/// How well one capability works for one language.
///
/// The whole point of this enum is to stop the app claiming things that were
/// never checked. There is a real, visible difference between "we wrote the
/// translation and a native speaker approved it" and "the code path exists but
/// nobody has ever run it on a phone".
enum CapabilityStatus {
  /// Built, and confirmed correct by a human.
  verified('Verified', 'Built and checked.'),

  /// Built, but NOT reviewed by a native speaker. Usable for a demo, not
  /// something to present as finished.
  draft('Draft', 'Translated but not yet reviewed by a native speaker.'),

  /// Wired up and shown to work, but quality is uneven or unproven at scale.
  /// Usable in a demo with that caveat stated out loud.
  experimental('Experimental', 'Works, but quality is not yet proven.'),

  /// The architecture supports it and the language code is wired up, but it
  /// has never been run for real, so we do not know whether it works.
  untested('Untested', 'Architecture ready. Never actually run.'),

  /// Not supported yet. The app falls back to English.
  notAvailable('Not available', 'Not built yet. English is shown instead.');

  const CapabilityStatus(this.label, this.description);

  final String label;
  final String description;

  bool get isUsable => this == verified || this == draft;

  /// True for anything we are willing to let a user rely on at all.
  bool get isWorking =>
      this == verified || this == draft || this == experimental;
}

/// One language the app knows about.
///
/// Note the four SEPARATE capability fields. A language can have a perfectly
/// good UI translation while having no speech recognition at all — treating
/// "supported" as one yes/no flag is exactly how projects end up over-claiming.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.endonym,
    required this.ui,
    required this.textAi,
    required this.speechToText,
    required this.textToSpeech,
    this.speechLocaleTag,
    this.scriptNote,
  });

  /// ISO 639 code. Used as the storage key and the translation map key.
  final String code;

  final String englishName;

  /// The language's name written in its own language and script. This is what
  /// a speaker actually looks for on a language list — someone who reads only
  /// Assamese cannot find their language in a list that says "Assamese".
  final String endonym;

  final CapabilityStatus ui;
  final CapabilityStatus textAi;
  final CapabilityStatus speechToText;
  final CapabilityStatus textToSpeech;

  /// The BCP-47 tag we would hand to Android's speech engine, e.g. 'as-IN'.
  ///
  /// Null means no widely-recognised tag exists, which is itself useful
  /// information: it tells us speech support is unlikely rather than merely
  /// unimplemented.
  final String? speechLocaleTag;

  /// Anything a reviewer should know about the script choice.
  final String? scriptNote;

  bool get hasTranslation => ui.isUsable;
}

/// English: the language the strings are originally written in, and the
/// fallback whenever a translation is missing.
const AppLanguage kEnglish = AppLanguage(
  code: 'en',
  englishName: 'English',
  endonym: 'English',
  ui: CapabilityStatus.verified,
  textAi: CapabilityStatus.experimental,
  speechToText: CapabilityStatus.untested,
  textToSpeech: CapabilityStatus.untested,
  speechLocaleTag: 'en-IN',
);

/// Used when the user has not chosen a language yet.
const AppLanguage kDefaultLanguage = kEnglish;

/// Every language the app offers, covering the eight North-Eastern states.
///
/// HONEST STATUS, as of today:
///   * textAi was MEASURED on 27 September 2026, three samples per language
///     against the live model, and each row below says what was observed:
///       - en, bn, ne: correct language and script every time.
///       - as: Assamese script every time, with Assamese-specific letters.
///       - mni: Bengali-script Manipuri twice, English once.
///       - lus, kha: plausible output, but both are Latin-script, so nothing
///         in the code can tell Mizo or Khasi from English. Untested means
///         exactly that: a person still has to read it.
///       - brx: asked for Bodo, the model returned fluent HINDI. Marked not
///         available rather than pretending.
///       - grt, trp: the model declines and answers in English, and now says
///         so honestly. Marked not available.
///     No language is `verified` for AI: that needs a native speaker.
///   * speechToText and textToSpeech are `untested` everywhere, because no
///     speech code has been written and nothing has been run on a device.
///   * ui is `verified` only for English (the strings were written in it) and
///     `draft` for the three languages that have translations which still need
///     a native speaker's review.
///
/// Changing any of these to `verified` requires actually testing it.
const List<AppLanguage> kAppLanguages = [
  kEnglish,
  AppLanguage(
    code: 'as',
    englishName: 'Assamese',
    endonym: 'অসমীয়া',
    ui: CapabilityStatus.draft,
    textAi: CapabilityStatus.experimental,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    speechLocaleTag: 'as-IN',
  ),
  AppLanguage(
    code: 'bn',
    englishName: 'Bengali',
    endonym: 'বাংলা',
    ui: CapabilityStatus.draft,
    textAi: CapabilityStatus.experimental,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    speechLocaleTag: 'bn-IN',
  ),
  AppLanguage(
    code: 'ne',
    englishName: 'Nepali',
    endonym: 'नेपाली',
    ui: CapabilityStatus.draft,
    textAi: CapabilityStatus.experimental,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    speechLocaleTag: 'ne-NP',
  ),
  AppLanguage(
    code: 'brx',
    englishName: 'Bodo',
    endonym: 'बड़ो',
    ui: CapabilityStatus.notAvailable,
    textAi: CapabilityStatus.notAvailable,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    scriptNote: 'Written in Devanagari.',
  ),
  AppLanguage(
    code: 'mni',
    englishName: 'Manipuri (Meitei)',
    endonym: 'Meitei',
    ui: CapabilityStatus.notAvailable,
    textAi: CapabilityStatus.untested,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    scriptNote:
        'Also written মৈতৈলোন্ in Bengali script, and in Meetei Mayek '
        '(ꯃꯤꯇꯩꯂꯣꯟ), which would need a bundled font.',
  ),
  AppLanguage(
    code: 'lus',
    englishName: 'Mizo',
    endonym: 'Mizo tawng',
    ui: CapabilityStatus.notAvailable,
    textAi: CapabilityStatus.untested,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    scriptNote: 'Written in Latin script.',
  ),
  AppLanguage(
    code: 'kha',
    englishName: 'Khasi',
    endonym: 'Khasi',
    ui: CapabilityStatus.notAvailable,
    textAi: CapabilityStatus.untested,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    scriptNote: 'Fuller native name: Ka Ktien Khasi. Latin script.',
  ),
  AppLanguage(
    code: 'grt',
    englishName: 'Garo',
    endonym: 'Garo',
    ui: CapabilityStatus.notAvailable,
    textAi: CapabilityStatus.notAvailable,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    scriptNote: 'Fuller native name: A·chik. Latin script.',
  ),
  AppLanguage(
    code: 'trp',
    englishName: 'Kokborok (Tripuri)',
    endonym: 'Kokborok',
    ui: CapabilityStatus.notAvailable,
    textAi: CapabilityStatus.notAvailable,
    speechToText: CapabilityStatus.untested,
    textToSpeech: CapabilityStatus.untested,
    scriptNote: 'Written in both Latin and Bengali script.',
  ),
];

/// Finds a language by code, falling back to English for anything unknown.
AppLanguage languageForCode(String? code) {
  for (final language in kAppLanguages) {
    if (language.code == code) return language;
  }
  return kDefaultLanguage;
}
