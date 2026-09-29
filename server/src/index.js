import cors from 'cors';
import express from 'express';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { openDatabase } from './db/database.js';
import { createCareRouter } from './caregiver/routes.js';
import { seedDemoData } from './caregiver/demo.js';

import { RateLimiter, TtlCache } from './cache.js';
import { config, isGeminiConfigured, redact } from './config.js';
import { AiErrorCode, callGemini, GatewayError } from './gemini.js';
import { generateAdventureText } from './adventure/variation.js';
import { resolveLanguageUsed } from './languages.js';
import {
  buildGamePrompt,
  buildGeneralPrompt,
  buildMemoryPrompt,
  GAME_SCHEMA,
  GAME_SYSTEM,
  buildReminderPrompt,
  REMINDER_SCHEMA,
  REMINDER_SYSTEM,
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

// ---------------------------------------------------------------- caregiver
//
// A second product sharing one process: the patient app's Gemini gateway and
// the caregiver website. They are separate concerns and separate routers,
// mounted side by side so there is one thing to deploy and one URL to
// remember. Nothing below touches /api/ai.
const careDatabase = openDatabase();
const demo = seedDemoData(careDatabase);
const { router: careRouter } = createCareRouter(careDatabase);
app.use('/api/care', careRouter);

// The site itself. Static files, no build step.
const here = dirname(fileURLToPath(import.meta.url));
app.use(express.static(join(here, '..', 'public')));

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
// The caregiver site is served at / by express.static above, so this JSON
// description moves to /api where it does not shadow index.html.
app.get('/api', (_request, response) => {
  response.json({
    service: 'MindPal AI gateway',
    running: true,
    geminiConfigured: isGeminiConfigured(),
    endpoints: {
      health: 'GET /api/health',
      ai: 'POST /api/ai',
      caregiverSite: 'GET /',
      caregiverApi: 'POST /api/care/login',
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

/**
 * The words for one Festival Quest adventure.
 *
 * The app sends the slot names it is willing to have rewritten and the short
 * list of mechanical choices it will accept. Nothing about the game's rules
 * comes back from here: this endpoint returns strings and one item id, and the
 * app can only put them into the text slots of its own hand-written template.
 *
 * The app validates the finished adventure itself — structure and a full
 * solve — before anybody plays it, and falls back to the bundled adventure if
 * that fails. This endpoint failing is therefore never worse than an adventure
 * the player has already got.
 */
app.post('/api/adventure', async (request, response) => {
  const id = `#${++requestCounter}`;
  const started = Date.now();
  const log = (line) => console.log(`[adventure] ${id} ${line}`);

  const { slots, soldOutOptions, currentText, seed } = request.body ?? {};

  if (!Array.isArray(slots) || slots.length === 0) {
    return response.status(400).json({
      success: false,
      code: 'bad_request',
      error: 'Send the list of slots to fill.',
    });
  }

  if (!limiter.tryConsume()) {
    log('rejected: rate limit');
    return response.status(429).json({
      success: false,
      code: AiErrorCode.rateLimited,
      error: 'Too many requests just now. Please try again in a minute.',
      retryable: true,
    });
  }

  // Which thing has sold out is the ONE mechanical choice, and it is made here
  // from the list the app sent — the app checks it again on the way in, because
  // a client should not trust a server's word about its own rules either.
  const options = Object.entries(soldOutOptions ?? {});
  if (options.length === 0) {
    return response.status(400).json({
      success: false,
      code: 'bad_request',
      error: 'Send the sold-out options this app accepts.',
    });
  }
  const [soldOutItemId, alternativeItemId] =
    options[Math.floor(Math.random() * options.length)];

  try {
    const result = await generateAdventureText({
      slots,
      currentText: currentText ?? {},
      soldOutItemId,
      alternativeItemId,
      seed: typeof seed === 'string' ? seed.slice(0, 40) : undefined,
      log,
    });

    log(
      `ok model=${result.model} slots=${Object.keys(result.text).length} ` +
        `rejected=${result.rejected.length} ${Date.now() - started}ms`,
    );

    return response.json({
      success: true,
      soldOutItemId,
      alternativeItemId,
      text: result.text,
      // Returned so a failure is diagnosable from the app's logs rather than
      // only from the server's.
      rejectedSlots: result.rejected.slice(0, 20),
      model: result.model,
    });
  } catch (error) {
    if (error instanceof GatewayError) {
      log(`FAILED code=${error.code} ${Date.now() - started}ms`);
      return response.status(error.httpStatus).json({
        success: false,
        code: error.code,
        error: redact(error.message),
        retryable: error.retryable,
      });
    }
    console.error(`[adventure] ${id} unexpected failure:`, redact(String(error)));
    return response.status(500).json({
      success: false,
      code: 'server_error',
      error: 'The adventure writer hit an unexpected problem.',
      retryable: true,
    });
  }
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
    case 'parse_reminder':
      return handleReminderParse(payload, log);
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

/**
 * Turns one spoken sentence into reminder fields.
 *
 * Everything is re-checked here rather than trusted: an hour outside 0-23, a
 * category we do not have, or a repeat we do not support would all become a
 * broken reminder on the phone. Anything that fails a check is dropped and
 * reported as missing, so the confirmation screen asks the user instead of
 * saving a guess.
 */
async function handleReminderParse(payload, log) {
  const { data, model } = await callGemini({
    systemInstruction: REMINDER_SYSTEM,
    prompt: buildReminderPrompt(payload),
    schema: REMINDER_SCHEMA,
    maxOutputTokens: 512,
    log,
  });

  const missing = new Set(
    Array.isArray(data.missing)
      ? data.missing.filter((item) => typeof item === 'string')
      : [],
  );

  const title = typeof data.title === 'string' ? data.title.trim() : '';
  if (title.length === 0) missing.add('title');

  const hour = Number.isInteger(data.hour) ? data.hour : null;
  const minute = Number.isInteger(data.minute) ? data.minute : 0;
  const timeIsValid =
    hour !== null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  if (!timeIsValid) missing.add('time');

  const CATEGORIES = [
    'dailyActivity', 'meal', 'appointment', 'medicine', 'personal', 'other',
  ];
  const category = CATEGORIES.includes(data.category) ? data.category : 'other';
  const repeat = data.repeat === 'daily' ? 'daily' : 'once';

  return {
    success: true,
    model,
    understood: data.understood !== false && missing.size < 2,
    title,
    // Null rather than a default: the app must not be able to mistake a
    // missing time for midnight.
    hour: timeIsValid ? hour : null,
    minute: timeIsValid ? minute : null,
    repeat,
    category,
    notes: typeof data.notes === 'string' ? data.notes.trim() : '',
    missing: [...missing],
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
    demo.seeded
      ? `Caregiver site at / with demo accounts (password ${demo.password})`
      : 'Caregiver site at / (existing data kept)',
  );
  console.log(
    isGeminiConfigured()
      ? 'GEMINI_API_KEY is set.'
      : 'GEMINI_API_KEY is NOT set — /api/ai will return 503 and the app will '
        + 'use its offline fallback.',
  );
});

export { app };
