/**
 * Reads configuration from the environment.
 *
 * The API key is read here and NEVER leaves this process: it is not logged,
 * not returned by any endpoint, and not included in any error message. The
 * only reason this gateway exists at all is to keep the key off the phone —
 * anything shipped in an APK or a web bundle can be extracted in minutes.
 */

export const config = {
  apiKey: process.env.GEMINI_API_KEY ?? '',
  model: process.env.GEMINI_MODEL ?? 'gemini-2.5-flash',
  port: Number(process.env.PORT ?? 8787),
  allowedOrigin: process.env.ALLOWED_ORIGIN ?? '*',
  maxRequestsPerMinute: Number(process.env.MAX_REQUESTS_PER_MINUTE ?? 20),
  requestTimeoutMs: Number(process.env.REQUEST_TIMEOUT_MS ?? 15000),

  // Newer Gemini models "think" before answering, and those thinking tokens
  // come out of the same budget as the reply. Set GEMINI_THINKING_BUDGET=0 to
  // switch thinking off. Left unset by default, because not every model
  // accepts the parameter and sending it blindly would cause a 400.
  thinkingBudget:
    process.env.GEMINI_THINKING_BUDGET === undefined
      ? null
      : Number(process.env.GEMINI_THINKING_BUDGET),
};

export const isGeminiConfigured = () => config.apiKey.trim().length > 0;

/**
 * Removes anything key-shaped from text before it is logged or returned.
 *
 * Google keys start with "AIza". Upstream error bodies sometimes echo the
 * request back, so this runs over every message that leaves the process.
 */
export function redact(text) {
  if (typeof text !== 'string') return text;

  // Google AI Studio keys start with "AIza"; other Google credential shapes
  // start with "AQ.". Both are scrubbed, and the exact configured key is
  // scrubbed below whatever shape it happens to be.
  let safe = text
    .replaceAll(/AIza[0-9A-Za-z_-]{10,}/g, '[REDACTED_KEY]')
    .replaceAll(/AQ\.[0-9A-Za-z._-]{10,}/g, '[REDACTED_KEY]');
  if (config.apiKey.trim().length > 0) {
    safe = safe.replaceAll(config.apiKey, '[REDACTED_KEY]');
  }
  return safe;
}
