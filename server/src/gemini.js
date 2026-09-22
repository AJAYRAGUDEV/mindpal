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
  constructor(
    code,
    message,
    httpStatus = 502,
    { retryable = true, upstreamStatus = null } = {},
  ) {
    super(message);
    this.code = code;
    this.httpStatus = httpStatus;
    // Whether asking again in a moment could plausibly succeed. A busy model
    // is retryable; a rejected key is not. The app uses this to choose between
    // "please try again" and "smart answers are not set up".
    this.retryable = retryable;
    this.upstreamStatus = upstreamStatus;
  }
}

/**
 * Calls Gemini and returns `{ data, model, attempts }`, where `data` is the
 * parsed JSON object the model produced and `model` is the one that answered.
 *
 * WHY A CHAIN OF MODELS. On the free tier Google sheds load on its newest
 * models with 503 UNAVAILABLE ("high demand"), and it retires older names
 * with 404 while still listing them. Measured on 22 Sep 2026 with this
 * gateway's exact request shape: gemini-3.6-flash answered 1 request in 3,
 * gemini-2.5-flash answered none (404), and the *-lite and *-preview models
 * answered 3 in 3 in about a second. A single fixed model name is therefore
 * a coin toss; a chain is not. Each model gets one attempt, with its own
 * deadline, and the first usable answer wins.
 *
 * Uses the REST API directly rather than a client library: one less
 * dependency to keep in step, and the request is visible in one place, which
 * matters when you are debugging why a model rejected something.
 *
 * The key travels in the `x-goog-api-key` header, not the query string, so it
 * never lands in a URL that might be logged by a proxy. It is never logged
 * here either: every message that could echo it passes through redact().
 */
export async function callGemini({
  systemInstruction,
  prompt,
  schema,
  maxOutputTokens = 2048,
  log = () => {},
}) {
  if (!isGeminiConfigured()) {
    throw new GatewayError(
      AiErrorCode.notConfigured,
      'The AI gateway has no GEMINI_API_KEY configured.',
      503,
      { retryable: false },
    );
  }

  const attempts = [];
  let lastError = null;

  for (const model of config.modelChain) {
    const started = Date.now();
    try {
      const data = await attemptModel(model, {
        systemInstruction,
        prompt,
        schema,
        maxOutputTokens,
      });
      const ms = Date.now() - started;
      attempts.push(`${model}:ok/${ms}ms`);
      log(`model=${model} ok ${ms}ms`);
      return { data, model, attempts };
    } catch (error) {
      const ms = Date.now() - started;
      if (!(error instanceof GatewayError)) throw error;

      lastError = error;
      const status = error.upstreamStatus ?? error.code;
      attempts.push(`${model}:${status}/${ms}ms`);

      // A bad key or a malformed request will fail identically on every
      // model. Stop now rather than burning three attempts to learn nothing.
      if (!error.retryable) {
        log(`model=${model} ${status} ${ms}ms, not retryable, stopping`);
        break;
      }
      log(`model=${model} ${status} ${ms}ms, trying next model`);
    }
  }

  // Re-thrown with the full attempt list so the log line explains itself.
  lastError.attempts = attempts;
  throw lastError;
}

/** One request to one model. Throws GatewayError on anything but a usable answer. */
async function attemptModel(
  model,
  { systemInstruction, prompt, schema, maxOutputTokens },
) {
  // AbortController is how you put a deadline on fetch. Without it a hung
  // upstream would hold the request open until the client gives up.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.requestTimeoutMs);

  let response;
  try {
    response = await fetch(
      `${BASE_URL}/${encodeURIComponent(model)}:generateContent`,
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
        { upstreamStatus: 'timeout' },
      );
    }
    throw new GatewayError(
      AiErrorCode.network,
      'Could not reach the AI service.',
      502,
      { upstreamStatus: 'network' },
    );
  } finally {
    clearTimeout(timer);
  }

  if (!response.ok) {
    const body = redact(await response.text().catch(() => ''));
    // One line, with the status Google sent, so a 503 "high demand" and a
    // 404 "model retired" are distinguishable at a glance in the Render log.
    const summary = summariseUpstreamError(body);
    console.error(
      `[gemini] ${model} responded ${response.status}${summary ? ` ${summary}` : ''}`,
    );

    if (response.status === 429) {
      throw new GatewayError(
        AiErrorCode.rateLimited,
        'The AI service is busy. Please try again shortly.',
        429,
        { upstreamStatus: 429 },
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new GatewayError(
        AiErrorCode.notConfigured,
        'The AI service rejected this gateway\'s credentials.',
        503,
        { retryable: false, upstreamStatus: response.status },
      );
    }
    if (response.status === 400) {
      throw new GatewayError(
        AiErrorCode.upstream,
        'The AI service rejected the request.',
        502,
        { retryable: false, upstreamStatus: 400 },
      );
    }
    // 404 (model retired), 500, 503 (high demand): the next model may do
    // better, so these stay retryable.
    throw new GatewayError(
      AiErrorCode.upstream,
      'The AI service returned an error.',
      502,
      { upstreamStatus: response.status },
    );
  }

  const payload = await response.json().catch(() => null);
  const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (typeof text !== 'string' || text.trim().length === 0) {
    // Log WHY, so an empty answer is diagnosable rather than mysterious.
    const reason = payload?.candidates?.[0]?.finishReason ?? 'unknown';
    console.error(
      `[gemini] ${model} returned no text (finishReason: ${reason}). ` +
        'If this is MAX_TOKENS, set GEMINI_THINKING_BUDGET=0.',
    );
    throw new GatewayError(
      AiErrorCode.invalidResponse,
      'The AI service returned nothing usable.',
      502,
      { upstreamStatus: `empty:${reason}` },
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
      { upstreamStatus: 'malformed' },
    );
  }
}

/** "UNAVAILABLE: This model is currently experiencing high demand" from a Google error body. */
function summariseUpstreamError(body) {
  try {
    const parsed = JSON.parse(body);
    const status = parsed?.error?.status;
    const message = parsed?.error?.message;
    if (!status && !message) return '';
    return `${status ?? ''}${message ? `: ${String(message).slice(0, 160)}` : ''}`;
  } catch {
    return body.slice(0, 160).replaceAll(/\s+/g, ' ');
  }
}
