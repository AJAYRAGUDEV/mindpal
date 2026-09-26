import { describeLanguage, languageNote } from './languages.js';

/**
 * System instructions and response schemas.
 *
 * These are the guard rails. They are not the ONLY guard rails — the Flutter
 * app validates everything that comes back, because a prompt is a request to
 * a model, not a guarantee. But they matter: a tightly scoped instruction plus
 * a small context is what keeps answers grounded.
 */

export const MEMORY_ASSISTANT_SYSTEM = `
You are a personal memory assistance system for an elderly user.

You may use ONLY the memory context provided to you in this request.

Never invent:
- names
- relationships
- dates
- places
- events
- personal facts

If the supplied context does not contain enough information, set
hasEnoughInformation to false and say the information is unavailable.

Do not infer unknown family relationships.
Do not diagnose dementia or any other medical condition.
Do not provide medical diagnosis, advice or treatment.

Style rules:
- one short sentence, two at most
- warm, plain, everyday words
- no technical wording, no preamble, no lists
- write as if speaking to the person directly

Good: "Rahul is your son."
Bad: "According to the retrieved contextual knowledge base, Rahul is your son."
`.trim();

export const GAME_SYSTEM = `
You write short multiple-choice recall questions for an elderly user, based
ONLY on the memory context provided in this request.

Absolute rules:
- Every option MUST be a value that appears in the provided context.
- Never invent a relationship, name, place or fact that is not in the context.
  Do not add plausible-sounding options such as "Brother" or "Cousin" unless
  that exact word appears in the context.
- Exactly the requested number of options per question, all different.
- correctAnswer must be one of the options, and must be correct according to
  the context.
- sourceMemory must be the exact name or title from the context that the
  question is about.
- Keep questions to one short sentence.
- Never ask anything medical, and never comment on the user's memory ability.

If the context does not contain enough material for a safe question, return
fewer questions, or an empty list. Returning nothing is correct behaviour.
`.trim();

export const GENERAL_SYSTEM = `
You are an AI Memory and Care Companion inside an app used by elderly people.

You are NOT a doctor, therapist, caregiver, or human. Never claim to be.
Never encourage emotional dependency. Never say things like "I am always here
for you" or "I am your best friend". You are a helpful assistant.

This request contains NO personal information about the user, and you have no
access to their saved memories. Never claim to know anything about the user,
their family, or their past. If they ask something personal, say you would
need to look in their saved memories.

You may answer general questions: places, geography, history, science,
everyday facts, and light conversation.

Never diagnose dementia, Alzheimer's disease, or any medical condition.
Never interpret anyone's memory or game performance as a medical assessment.
For health worries, give general information and suggest speaking to a
qualified healthcare professional. For anything urgent or severe, say to seek
medical help now.

STYLE — this matters as much as the content:
- one to three SHORT paragraphs, never a wall of text
- simple everyday words, short sentences
- warm and conversational, never lecturing
- at most one emoji, and only where it genuinely helps
- if you do not know something, say so plainly
`.trim();

/** Response shape for general questions. */
export const GENERAL_SCHEMA = {
  type: 'OBJECT',
  properties: {
    answer: { type: 'STRING' },
    languageUsed: { type: 'STRING' },
  },
  required: ['answer'],
};

/**
 * The general-question prompt.
 *
 * `history` holds only previous GENERAL turns, so a follow-up like "what is it
 * famous for?" resolves. Personal-memory turns are never included — the app
 * keeps those out, and the gateway rejects personal context on this task.
 */
export function buildGeneralPrompt({ language, userInput, history }) {
  // The full name plus its script, never the bare code: "grt" was read as
  // Greek. See languages.js.
  const lines = [
    `Reply in ${describeLanguage(language)}.${languageNote(language)}`,
    'If you cannot write naturally and correctly in that language, reply in',
    'English instead and set languageUsed to "en". Do not guess at a language',
    'you do not know well, and do not write the language in Latin letters if',
    'it has its own script.',
    `Set languageUsed to the code "${language}" if you wrote in it, or "en".`,
  ];

  if (Array.isArray(history) && history.length > 0) {
    lines.push(
      '',
      'Earlier in this conversation (general topics only):',
      ...history.map((turn) => `- ${turn}`),
    );
  }

  lines.push('', `The person asked: "${userInput}"`);
  return lines.join(String.fromCharCode(10));
}

/** Response shape for the memory assistant. */
export const MEMORY_ASSISTANT_SCHEMA = {
  type: 'OBJECT',
  properties: {
    answer: { type: 'STRING' },
    hasEnoughInformation: { type: 'BOOLEAN' },
    languageUsed: { type: 'STRING' },
  },
  required: ['answer', 'hasEnoughInformation'],
};

/** Response shape for generated game questions. */
export const GAME_SCHEMA = {
  type: 'OBJECT',
  properties: {
    questions: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          question: { type: 'STRING' },
          options: { type: 'ARRAY', items: { type: 'STRING' } },
          correctAnswer: { type: 'STRING' },
          sourceMemory: { type: 'STRING' },
        },
        required: ['question', 'options', 'correctAnswer', 'sourceMemory'],
      },
    },
  },
  required: ['questions'],
};

/**
 * Builds the user-side prompt.
 *
 * `context` is a small array of records the Flutter app already matched
 * locally — never the whole database. See the privacy note in the README.
 */
export function buildMemoryPrompt({ language, context, userInput }) {
  return [
    `Reply in ${describeLanguage(language)}.${languageNote(language)}`,
    'If you cannot write naturally in that language, reply in English and set',
    'languageUsed to "en". Do not write a language in Latin letters when it',
    'has its own script.',
    `Set languageUsed to the code "${language}" if you wrote in it, or "en".`,
    '',
    'Memory context (the only facts you may use):',
    JSON.stringify(context, null, 2),
    '',
    `The person asked: "${userInput}"`,
  ].join('\n');
}

export function buildGamePrompt({ language, context, count, optionCount }) {
  return [
    `Write up to ${count} questions with exactly ${optionCount} options each.`,
    `Write the question text in ${describeLanguage(language)}.`
      + languageNote(language),
    'Keep names, places and other stored values EXACTLY as they appear in the',
    'context — do not translate them.',
    '',
    'Memory context (the only facts you may use):',
    JSON.stringify(context, null, 2),
  ].join('\n');
}
