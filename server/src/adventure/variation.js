import { callGemini, GatewayError, AiErrorCode } from '../gemini.js';

/**
 * Generating the WORDS of a Festival Quest adventure.
 *
 * The app sends the list of text slots it is willing to have rewritten and the
 * short list of mechanical choices it will accept. Gemini fills in the words.
 * It is never asked for a rule, a price, a requirement, a clue relationship or
 * an ending condition, because the app has nowhere to put one: the structure is
 * a hand-written template and generated text can only land in its slots.
 *
 * So the worst a bad generation can do is produce an adventure that reads
 * oddly. It cannot produce one that cannot be finished — and the app still runs
 * its own validator and solver over the result before anybody plays it.
 */

/** Slots the model is not allowed to touch, whatever the client asks for. */
const FORBIDDEN_SLOT_PREFIXES = ['item.', 'price.', 'coins', 'effect.', 'requires.'];

/** The most slots one request may ask for. A guard on prompt size, not taste. */
const MAX_SLOTS = 220;

const MAX_VALUE_LENGTH = 600;

/** How many times to ask again when the answer is unusable. */
const MAX_ATTEMPTS = 3;

const SYSTEM_INSTRUCTION = `
You write the words for a short, gentle adventure game played by older adults,
including people with memory difficulties.

You are given a list of SLOT NAMES. Return a JSON object whose keys are exactly
those slot names and whose values are the replacement text.

Rules you must follow:
- Keep every value SHORT. One or two sentences at most. Tile labels and quest
  titles are a few words.
- Plain, warm, everyday English. No jargon. No exclamation marks in every line.
- Never threaten, rush or scold the player. There are no timers and no failure.
- Never mention scores, points, levels, dementia, memory loss, therapy or any
  medical idea.
- Keep the MEANING of each original line. You are rewording one story, not
  writing another. A line that gave the player a fact must still give that
  fact, about the same thing; a line that asked a question must still ask it.
  A clue must still point where it pointed. This is the most important rule
  here: the player solves a mystery by reasoning from these sentences, so a
  clue that quietly changes subject makes the puzzle unsolvable.
- Never write an internal id such as palm_sugar or clue_basket into a sentence.
  Use the ordinary name of the thing.
- Keep every name of a real object exactly as it is given to you (foods, tools,
  instruments, cloth). Those are real cultural objects and must not be renamed
  or invented.
- People and the village are fictional. You may rename the PEOPLE. Use given
  names that suit the region you are told about, and no other region.
- Do not present the story as a traditional tale or as folklore. Do not add
  facts about the festival that were not already in the text you were given.

Return only the JSON object. Every key must come from the list you were given.
`.trim();

/**
 * Builds the prompt: the slots, their current text, and the one mechanical
 * choice being made.
 */
function buildPrompt({
  slots,
  currentText,
  soldOutItemId,
  alternativeItemId,
  itemNames = {},
  festival,
  region,
  seed,
}) {
  // Names, never ids. A prompt that says `palm_sugar` gets `palm_sugar` back in
  // a sentence a player then reads.
  const soldOutName = itemNames[soldOutItemId] ?? soldOutItemId;
  const alternativeName = itemNames[alternativeItemId] ?? alternativeItemId;

  const lines = [
    festival
      ? `This adventure is set at ${festival}${region ? `, in ${region}` : ''}.`
      : '',
    festival
      ? 'Keep it there. Names of people should suit that place, and nothing'
      : '',
    festival ? 'should be moved to a different festival or region.' : '',
    festival ? '' : '',
    'Reword each slot below. The CURRENT TEXT is given after each slot name.',
    'Say the same thing in different words. Do not change what happens, who',
    'knows what, or what any line tells the player.',
    '',
    `In this telling the market has run out of ${soldOutName}.`,
    `${alternativeName} is the acceptable alternative.`,
    'Only the lines that already talk about what has sold out should mention',
    'this. Leave every other line about its own subject.',
    '',
  ];

  if (seed) {
    lines.push(`A word to set the mood, if it helps: "${seed}".`, '');
  }

  lines.push('SLOTS (name, then the current text):', '');
  for (const slot of slots) {
    const current = currentText?.[slot];
    lines.push(current ? `${slot}\n  ${current}` : slot);
  }

  return lines.join('\n');
}

/**
 * Drops anything the app did not ask for, or that is the wrong shape.
 *
 * [forbidden] holds the internal ids of things — `palm_sugar`, `clue_basket`.
 * A value containing one is dropped, because it would put a database key in
 * front of a player. The prompt asks for ordinary names and the model usually
 * obliges; "usually" is not a guarantee, and this is. A dropped value simply
 * keeps its original wording.
 */
export function sanitise(raw, allowedSlots, forbidden = []) {
  const allowed = new Set(allowedSlots);
  const ids = forbidden.filter(
    (id) => typeof id === 'string' && id.includes('_'),
  );
  const text = {};
  const rejected = [];

  for (const [key, value] of Object.entries(raw ?? {})) {
    if (!allowed.has(key)) {
      rejected.push(`${key}: not a slot this app asked for`);
      continue;
    }
    if (typeof value !== 'string') {
      rejected.push(`${key}: not text`);
      continue;
    }
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      rejected.push(`${key}: empty`);
      continue;
    }
    if (trimmed.length > MAX_VALUE_LENGTH) {
      rejected.push(`${key}: too long (${trimmed.length})`);
      continue;
    }
    const leaked = ids.find((id) => trimmed.includes(id));
    if (leaked) {
      rejected.push(`${key}: contains the internal id "${leaked}"`);
      continue;
    }
    text[key] = trimmed;
  }

  return { text, rejected };
}

/**
 * How much of what was asked for came back usable.
 *
 * A response that filled a handful of slots is not worth serving: the result
 * would be the bundled adventure with three sentences changed, which is a worse
 * experience than the bundled adventure and took a network round trip to get.
 */
function coverage(text, slots) {
  if (slots.length === 0) return 1;
  return Object.keys(text).length / slots.length;
}

const MIN_COVERAGE = 0.6;

/**
 * Asks Gemini for a set of words, retrying a bounded number of times.
 *
 * Throws GatewayError when there is nothing usable after the retries; the route
 * turns that into a plain message, and the app falls back to the bundled
 * adventure.
 */
export async function generateAdventureText({
  slots,
  currentText = {},
  soldOutItemId,
  alternativeItemId,
  itemNames = {},
  festival,
  region,
  seed,
  log = () => {},
}) {
  const usable = slots.filter(
    (slot) =>
      typeof slot === 'string' &&
      slot.length > 0 &&
      !FORBIDDEN_SLOT_PREFIXES.some((prefix) => slot.startsWith(prefix)),
  );

  if (usable.length === 0) {
    throw new GatewayError(
      AiErrorCode.invalidResponse,
      'No slots to fill.',
      400,
      { retryable: false },
    );
  }

  const slice = usable.slice(0, MAX_SLOTS);
  const attempts = [];
  let lastProblem = 'The model returned nothing usable.';

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      const { data, model } = await callGemini({
        systemInstruction: SYSTEM_INSTRUCTION,
        prompt: buildPrompt({
          slots: slice,
          currentText,
          soldOutItemId,
          alternativeItemId,
          itemNames,
          festival,
          region,
          seed,
        }),
        // No responseSchema: the key set is decided by the app and changes with
        // the adventure, and a schema of two hundred named string properties is
        // both unwieldy and more likely to be refused than plain JSON.
        maxOutputTokens: 8192,
        log,
      });

      const { text, rejected } = sanitise(data, slice, Object.keys(itemNames));
      const filled = coverage(text, slice);
      attempts.push(`try${attempt}:${model}/${Object.keys(text).length}slots`);

      if (filled >= MIN_COVERAGE) {
        log(`adventure text ok: ${Math.round(filled * 100)}% of slots`);
        return { text, rejected, attempts, model };
      }

      lastProblem =
        `only ${Math.round(filled * 100)}% of the slots came back usable`;
      log(`adventure text thin (${lastProblem}), retrying`);
    } catch (error) {
      if (!(error instanceof GatewayError)) throw error;
      attempts.push(`try${attempt}:${error.code}`);
      lastProblem = error.message;
      // A bad key or a malformed request fails the same way every time.
      if (!error.retryable) break;
    }
  }

  throw new GatewayError(
    AiErrorCode.upstream,
    `Could not write a new adventure: ${lastProblem}`,
    503,
    { retryable: true, attempts },
  );
}
