/**
 * Validates incoming requests before any Gemini call is made.
 *
 * Two reasons this runs first: a malformed request should never cost a Gemini
 * call from a limited free tier, and it should never reach the model at all.
 */

export const TASKS = ['memory_assistant', 'game_questions', 'general_knowledge'];

/** How much context one request may carry. */
const MAX_CONTEXT_RECORDS = 8;
const MAX_USER_INPUT_LENGTH = 300;

/**
 * Returns { ok: true, value } or { ok: false, error }.
 *
 * A plain result object rather than throwing: this is expected user input,
 * not an exceptional condition.
 */
export function validateAiRequest(body) {
  if (body === null || typeof body !== 'object') {
    return { ok: false, error: 'Request body must be a JSON object.' };
  }

  const { task, language, context, userInput, count, optionCount } = body;

  if (!TASKS.includes(task)) {
    return { ok: false, error: `task must be one of: ${TASKS.join(', ')}.` };
  }

  if (typeof language !== 'string' || language.trim().length === 0) {
    return { ok: false, error: 'language is required.' };
  }

  if (!Array.isArray(context)) {
    return { ok: false, error: 'context must be an array.' };
  }

  // A request carrying the whole address book is either a bug or a privacy
  // problem. Either way it is refused rather than forwarded.
  if (context.length > MAX_CONTEXT_RECORDS) {
    return {
      ok: false,
      error: `context may hold at most ${MAX_CONTEXT_RECORDS} records.`,
    };
  }

  // general_knowledge carries no personal context at all — it must stay
  // empty, so a bug can never turn a general question into a data leak.
  if (task === 'general_knowledge') {
    if (context.length > 0) {
      return {
        ok: false,
        error: 'general_knowledge must not carry personal context.',
      };
    }
    if (typeof userInput !== 'string' || userInput.trim().length === 0) {
      return { ok: false, error: 'userInput is required.' };
    }
    if (userInput.length > MAX_USER_INPUT_LENGTH) {
      return { ok: false, error: 'userInput is too long.' };
    }
  }

  if (task === 'memory_assistant') {
    if (typeof userInput !== 'string' || userInput.trim().length === 0) {
      return { ok: false, error: 'userInput is required for memory_assistant.' };
    }
    if (userInput.length > MAX_USER_INPUT_LENGTH) {
      return { ok: false, error: 'userInput is too long.' };
    }
  }

  return {
    ok: true,
    value: {
      task,
      language: language.trim(),
      context,
      userInput: typeof userInput === 'string' ? userInput.trim() : '',
      // Clamped rather than rejected: a silly number is not worth an error,
      // but it is worth capping the tokens it would cost.
      // Recent GENERAL turns only, so "what is it famous for?" resolves.
      // The app never puts a personal-memory turn in here.
      history: Array.isArray(body.history)
        ? body.history
            .filter((turn) => typeof turn === 'string')
            .slice(-4)
            .map((turn) => turn.slice(0, 300))
        : [],
      count: clamp(count, 1, 8, 5),
      optionCount: clamp(optionCount, 2, 5, 3),
    },
  };
}

function clamp(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, Math.round(number)));
}
