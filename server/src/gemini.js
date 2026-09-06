import { config, isGeminiConfigured, redact } from './config.js';

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

/** Errors this gateway can produce, so the app can react to each differently. */
export const AiErrorCode = {
  notConfigured: 'not_configured',
  timeout: 'timeout',
  rateLimited: 'rate_limited',
  upstream: 'upstream_error',
  invalidResponse: 'invalid_response',
  network: 'network_error',
};

export class GatewayError extends Error {
  constructor(code, message, httpStatus = 502) {
    super(message);
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

/**
 * Calls Gemini and returns the parsed JSON object it produced.
 *
 * Uses the REST API directly rather than a client library: one less dependency
 * to keep in step, and the request is visible in one place, which matters when
 * you are debugging why a model rejected something.
 *
 * The key travels in the `x-goog-api-key` header, not the query string, so it
 * never lands in a URL that might be logged by a proxy.
 */
export async function callGemini({
  systemInstruction,
  prompt,
  schema,
  maxOutputTokens = 2048,
}) {
  if (!isGeminiConfigured()) {
    throw new GatewayError(
      AiErrorCode.notConfigured,
      'The AI gateway has no GEMINI_API_KEY configured.',
      503,
    );
  }

  // AbortController is how you put a deadline on fetch. Without it a hung
  // upstream would hold the request open until the client gives up.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.requestTimeoutMs);

  let response;
  try {
    response = await fetch(
      `${BASE_URL}/${encodeURIComponent(config.model)}:generateContent`,
      {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': config.apiKey,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemInstruction }] },
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: {
            // Asking for JSON is far more reliable than parsing prose.
            responseMimeType: 'application/json',
            responseSchema: schema,
            // Low temperature: we want faithful phrasing of stored facts,
            // not creativity. Creativity here means invention.
            temperature: 0.2,
            // Deliberately generous. A thinking model burns this budget
            // reasoning before it emits a word, so a tight cap yields a
            // successful response containing no text at all.
            maxOutputTokens,
            ...(config.thinkingBudget === null
              ? {}
              : { thinkingConfig: { thinkingBudget: config.thinkingBudget } }),
          },
        }),
      },
    );
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new GatewayError(
        AiErrorCode.timeout,
        'The AI service took too long to reply.',
        504,
      );
    }
    throw new GatewayError(
      AiErrorCode.network,
      'Could not reach the AI service.',
      502,
    );
  } finally {
    clearTimeout(timer);
  }

  if (!response.ok) {
    const body = redact(await response.text().catch(() => ''));
    // Logged for the developer; the client gets a short, safe message.
    console.error(`Gemini responded ${response.status}: ${body.slice(0, 400)}`);

    if (response.status === 429) {
      throw new GatewayError(
        AiErrorCode.rateLimited,
        'The AI service is busy. Please try again shortly.',
        429,
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new GatewayError(
        AiErrorCode.notConfigured,
        'The AI service rejected this gateway’s credentials.',
        503,
      );
    }
    throw new GatewayError(
      AiErrorCode.upstream,
      'The AI service returned an error.',
      502,
    );
  }

  const payload = await response.json().catch(() => null);
  const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (typeof text !== 'string' || text.trim().length === 0) {
    // Log WHY, so an empty answer is diagnosable rather than mysterious.
    const reason = payload?.candidates?.[0]?.finishReason ?? 'unknown';
    console.error(
      `Gemini returned no text (finishReason: ${reason}). If this is ` +
        'MAX_TOKENS, set GEMINI_THINKING_BUDGET=0 in .env.',
    );
    throw new GatewayError(
      AiErrorCode.invalidResponse,
      'The AI service returned nothing usable.',
      502,
    );
  }

  try {
    return JSON.parse(text);
  } catch {
    // Even with responseMimeType set, a truncated reply is possible.
    throw new GatewayError(
      AiErrorCode.invalidResponse,
      'The AI service returned malformed data.',
      502,
    );
  }
}
