/**
 * What each language code actually means, and how to check the model obeyed.
 *
 * WHY THIS FILE EXISTS. The gateway used to put the bare ISO code into the
 * prompt — "Reply in this language: grt." Measured against the live model on
 * 27 September 2026, that produced:
 *
 *   grt  -> fluent GREEK, reported as languageUsed "Greek"
 *   mni  -> English text, reported as languageUsed "mni" (a false claim)
 *   as   -> Assamese words in Latin letters, not the Assamese script
 *   kha  -> Khasi, but reported as "Khasi" rather than "kha"
 *
 * Three separate faults: the code is ambiguous, the model over-claims, and
 * the reported value is free text the app cannot compare against a code.
 *
 * So: name the language in full, name its script, normalise what comes back
 * to a code, and verify the script rather than trusting the claim.
 */

/**
 * `script` is the Unicode range a genuine reply must contain.
 *
 * WHAT THIS CHECK PROVES, AND WHAT IT DOES NOT. It proves the reply is in the
 * right SCRIPT. It cannot prove it is in the right LANGUAGE, because scripts
 * are shared:
 *
 *   - Bodo, Nepali and Hindi all use Devanagari. Asked for Bodo, the model
 *     returned fluent Hindi ("सुप्रभात। कृपया अपनी दवा लें।") and this check
 *     passed it. Measured 27 September 2026.
 *   - Assamese, Bengali and Manipuri all use the Bengali-Assamese script.
 *   - Null means Latin script, where no range check is possible at all:
 *     "Chibai!" and "Hello!" are both Latin.
 *
 * The ranges below are written as literal characters: the Bengali-Assamese
 * block is U+0980 to U+09FF, and Devanagari is U+0900 to U+097F.
 *
 * So a passing check means "not obviously wrong", never "verified". Only a
 * native speaker can confirm the language itself, which is why no language is
 * marked verified for AI in the app's capability matrix.
 */
const LANGUAGES = {
  en: { name: 'English', script: null },
  as: {
    name: 'Assamese (অসমীয়া)',
    // Assamese uses the Bengali-Assamese script.
    script: /[ঀ-৿]/,
    note: 'Write in the Assamese script, not in Latin letters.',
  },
  bn: { name: 'Bengali (বাংলা)', script: /[ঀ-৿]/ },
  ne: { name: 'Nepali (नेपाली)', script: /[ऀ-ॿ]/ },
  brx: {
    name: 'Bodo (बड़ो)',
    script: /[ऀ-ॿ]/,
    note: 'Bodo is written in the Devanagari script.',
  },
  mni: {
    name: 'Manipuri, also called Meitei (মৈতৈলোন্)',
    script: /[ঀ-৿]/,
    note: 'Use the Bengali script, which is the form in common use.',
  },
  lus: { name: 'Mizo (Mizo tawng)', script: null },
  kha: { name: 'Khasi (Ka Ktien Khasi)', script: null },
  grt: {
    name: 'Garo, also called A·chik, spoken in Meghalaya, India',
    script: null,
    // The whole reason this file exists.
    note: 'This is NOT Greek. Garo is a Tibeto-Burman language of North-East India.',
  },
  trp: { name: 'Kokborok, the language of Tripura, India', script: null },
};

export const isKnownLanguage = (code) =>
  Object.prototype.hasOwnProperty.call(LANGUAGES, code);

/** "Assamese (অসমীয়া)" for the prompt; the code itself if we don't know it. */
export function describeLanguage(code) {
  return LANGUAGES[code]?.name ?? code;
}

/** The extra sentence a tricky language needs, or ''. */
export function languageNote(code) {
  const note = LANGUAGES[code]?.note;
  return note ? ` ${note}` : '';
}

/**
 * What language the reply is ACTUALLY in, as a code the app can compare.
 *
 * Takes what the model claimed and the text it produced, and trusts the text
 * over the claim wherever the script can settle it:
 *
 *   - target script present        -> the target code (it did the work)
 *   - target script absent         -> 'en' (whatever it says it did)
 *   - target is Latin-script       -> the claim, normalised to a code
 *
 * Returning 'en' when the script is missing is what makes the app's "shown in
 * English" notice truthful instead of decorative.
 */
export function resolveLanguageUsed(requestedCode, claimed, text) {
  const entry = LANGUAGES[requestedCode];
  const answer = typeof text === 'string' ? text : '';

  if (entry?.script) {
    return entry.script.test(answer) ? requestedCode : 'en';
  }

  // Latin-script target: the script test cannot help, so fall back to the
  // model's own claim, mapped from whatever spelling it used to a code.
  return normaliseClaim(claimed, requestedCode);
}

/** "Khasi" -> "kha", "English" -> "en", "grt" -> "grt". */
function normaliseClaim(claimed, requestedCode) {
  if (typeof claimed !== 'string' || claimed.trim() === '') {
    return requestedCode;
  }
  const value = claimed.trim().toLowerCase();

  if (isKnownLanguage(value)) return value;

  for (const [code, entry] of Object.entries(LANGUAGES)) {
    // Match on the plain name before the bracket: "Khasi (Ka Ktien Khasi)".
    const plain = entry.name.split('(')[0].trim().toLowerCase();
    if (value === plain || value.startsWith(plain)) return code;
  }

  // Something we do not recognise at all — Greek, say. Not the target.
  return 'en';
}
