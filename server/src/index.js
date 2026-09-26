import cors from 'cors';
import express from 'express';

import { RateLimiter, TtlCache } from './cache.js';
import { config, isGeminiConfigured, redact } from './config.js';
import { AiErrorCode, callGemini, GatewayError } from './gemini.js';
import { resolveLanguageUsed } from './languages.js';
import {
  buildGamePrompt,
  buildGeneralPrompt,
  buildMemoryPrompt,
  GAME_SCHEMA,
  GAME_SYSTEM,
  GENERAL_SCHEMA,
  GENERAL_SYSTEM,
  MEMORY_ASSISTANT_SCHEMA,
  MEMORY_ASSISTANT_SYSTEM,
} from './prompts.js';
import { validateAiRequest } from './validate.js';

const app = express();

// CORS. ALLOWED_ORIGIN may be "*" (fine for a public read-only demo with no
// cookies or auth) or a comma-separated list of exact origins, e.g.
//   https://mindpal.vercel.app,http://localhost:5000
const allowedOrigins = config.allowedOrigin
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: allowedOrigins.includes('*')
      ? '*'
      : (origin, callback) => {
          // A missing Origin header means curl or a same-origin request.
          if (!origin || allowedOrigins.includes(origin)) {
            return callback(null, true);
          }
          callback(new Error('Origin not allowed'));
        },
  }),
);
app.use(express.json({ limit: '32kb' }));

const cache = new TtlCache();
const limiter = new RateLimiter({ maxPerMinute: config.maxRequestsPerMinute });

// A short id per request so the lines for one request can be found together
// in the Render log. Not a secret, not stable across restarts, not meant to be.
let requestCounter = 0;

/**
 * What gets logged about a request, and deliberately what does not.
 *
 * Logged: task, language, the LENGTH of the question, how many context
 * records travelled, the origin, the model that answered, timing, outcome.
 * Never logged: the question itself, the context records, or anything from
 * the environment. The question is personal ("who is my daughter?") and the
 * context is the user's own vault. A debugging log is not a place for either.
 */
function describeRequest(payload, request) {
  return [
    `task=${payload.task}`,
    `lang=${payload.language}`,
    `input=${payload.userInput.length}ch`,
    `ctx=${payload.context.length}`,
    `history=${payload.history.length}`,
    `origin=${request.get('origin') ?? '-'}`,
  ].join(' ');
}

/// Opening the bare root URL in a browser is the first thing anyone does, and
/// a bare 404 there looks like the server is broken when it is fine. This says
/// what the server is and where the real endpoints are.
app.get('/', (_request, response) => {
  response.json({
    service: 'MindPal AI gateway',
    running: true,
    geminiConfigured: isGeminiConfigured(),
    endpoints: {
      health: 'GET /api/health',
      ai: 'POST /api/ai',
    },
    hint: 'Open /api/health to check the key is loaded.',
  });
});

/**
 * Lets the app find out whether AI is usable before offering it.
 *
 * Reports only WHETHER a key is configured, never the key or any part of it.
 */
app.get('/api/health', (_request, response) => {
  response.json({
    ok: true,
    geminiConfigured: isGeminiConfigured(),
    model: config.model,
    fallbackModels: config.fallbackModels,
  });
});

app.post('/api/ai', async (request, response) => {
  const validation = validateAiRequest(request.body);
  if (!validation.ok) {
    return response
      .status(400)
      .json({ success: false, code: 'bad_request', error: validation.error });
  }

  const payload = validation.value;
  const id = `#${++requestCounter}`;
  const started = Date.now();
  const log = (line) => console.log(`[ai] ${id} ${line}`);

  log(describeRequest(payload, request));

  if (!limiter.tryConsume()) {
    log('rejected: rate limit');
    return response.status(429).json({
      success: false,
      code: AiErrorCode.rateLimited,
      error: 'Too many AI requests just now. Please try again in a minute.',
    });
  }

  // Identical request within the cache window: answer without paying for a
  // second Gemini call.
  const cacheKey = TtlCache.keyFor(payload);
  const cached = cache.get(cacheKey);
  if (cached !== undefined) {
    log(`ok (cached) ${Date.now() - started}ms`);
    return response.json({ ...cached, cached: true });
  }

  try {
    const result = await runTask(payload, log);

    cache.set(cacheKey, result);
    log(`ok model=${result.model} ${Date.now() - started}ms`);
    return response.json({ ...result, cached: false });
  } catch (error) {
    if (error instanceof GatewayError) {
      const attempts = (error.attempts ?? []).join(', ');
      log(`FAILED code=${error.code} attempts=[${attempts}] ${Date.now() - started}ms`);
      return response.status(error.httpStatus).json({
        success: false,
        code: error.code,
        error: redact(error.message),
        // Lets the app say "please try again" only when that is true.
        retryable: error.retryable,
      });
    }

    console.error(`[ai] ${id} unexpected failure:`, redact(String(error)));
    return response.status(500).json({
      success: false,
      code: 'server_error',
      error: 'The AI gateway hit an unexpected problem.',
      retryable: true,
    });
  }
});

function runTask(payload, log) {
  switch (payload.task) {
    case 'memory_assistant':
      return handleMemoryAssistant(payload, log);
    case 'general_knowledge':
      return handleGeneralKnowledge(payload, log);
    default:
      return handleGameQuestions(payload, log);
  }
}

/**
 * General questions: places, facts, light conversation.
 *
 * Note what is NOT here: no personal context, and no grounding check against
 * the vault. A question about Shillong legitimately mentions Meghalaya, which
 * the user never typed — the grounding check that protects personal answers
 * would reject every correct answer here. The protection on this path is that
 * it is given no personal data at all.
 */
async function handleGeneralKnowledge(payload, log) {
  const { data, model } = await callGemini({
    systemInstruction: GENERAL_SYSTEM,
    prompt: buildGeneralPrompt(payload),
    schema: GENERAL_SCHEMA,
    maxOutputTokens: 1536,
    log,
  });

  const answer = typeof data.answer === 'string' ? data.answer.trim() : '';
  if (answer.length === 0) {
    throw new GatewayError(
      AiErrorCode.invalidResponse,
      'The AI service returned an empty answer.',
    );
  }

  return {
    success: true,
    text: answer,
    model,
    // Checked against the text, not taken on trust: a model asked for
    // Manipuri answered in English and reported "mni". See languages.js.
    languageUsed: resolveLanguageUsed(payload.language, data.languageUsed, answer),
  };
}

async function handleMemoryAssistant(payload, log) {
  const { data, model } = await callGemini({
    systemInstruction: MEMORY_ASSISTANT_SYSTEM,
    prompt: buildMemoryPrompt(payload),
    schema: MEMORY_ASSISTANT_SCHEMA,
    maxOutputTokens: 1024,
    log,
  });

  const answer = typeof data.answer === 'string' ? data.answer.trim() : '';
  if (answer.length === 0) {
    throw new GatewayError(
      AiErrorCode.invalidResponse,
      'The AI service returned an empty answer.',
    );
  }

  return {
    success: true,
    text: answer,
    model,
    hasEnoughInformation: data.hasEnoughInformation !== false,
    // What the model ACTUALLY wrote in, verified against the script where
    // the script can settle it. The app compares this with what it asked
    // for and tells the user when the two differ.
    languageUsed: resolveLanguageUsed(payload.language, data.languageUsed, answer),
  };
}

async function handleGameQuestions(payload, log) {
  const { data, model } = await callGemini({
    systemInstruction: GAME_SYSTEM,
    prompt: buildGamePrompt(payload),
    schema: GAME_SCHEMA,
    maxOutputTokens: 4096,
    log,
  });

  const raw = Array.isArray(data.questions) ? data.questions : [];

  // Shape-checked here; GROUNDING is checked again in the Flutter app against
  // the real database. Two independent checks, because this one only knows
  // what the request happened to carry.
  const questions = raw
    .filter(
      (item) =>
        item !== null &&
        typeof item === 'object' &&
        typeof item.question === 'string' &&
        typeof item.correctAnswer === 'string' &&
        typeof item.sourceMemory === 'string' &&
        Array.isArray(item.options) &&
        item.options.every((option) => typeof option === 'string'),
    )
    .map((item) => ({
      question: item.question.trim(),
      options: item.options.map((option) => option.trim()),
      correctAnswer: item.correctAnswer.trim(),
      sourceMemory: item.sourceMemory.trim(),
    }));

  return { success: true, questions, model };
}

app.use((_request, response) => {
  response.status(404).json({ success: false, error: 'Not found.' });
});

app.listen(config.port, () => {
  console.log(`MindPal AI gateway listening on http://localhost:${config.port}`);
  console.log(`Model: ${config.model}`);
  console.log(
    config.fallbackModels.length > 0
      ? `Fallback models: ${config.fallbackModels.join(', ')}`
      : 'Fallback models: none',
  );
  console.log(`Allowed origins: ${allowedOrigins.join(', ')}`);
  console.log(
    isGeminiConfigured()
      ? 'GEMINI_API_KEY is set.'
      : 'GEMINI_API_KEY is NOT set — /api/ai will return 503 and the app will '
        + 'use its offline fallback.',
  );
});

export { app };
