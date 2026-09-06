import '../l10n/app_language.dart';

/// Turning speech into text.
///
/// INTERFACE ONLY. There is no working implementation in this project. The
/// only class below reports itself unavailable and gives a reason. Nothing in
/// the app pretends otherwise, and the capability matrix says `untested` for
/// every language.
///
/// When this is implemented (speech_to_text on Android), the work is:
///   1. add the package and the RECORD_AUDIO permission,
///   2. write AndroidSpeechToText implements SpeechToTextService,
///   3. run it on a real phone for each language and record what actually
///      worked,
///   4. only then change that language's status in app_language.dart.
///
/// Step 3 is not optional. Android's speech engine supports a specific set of
/// locales that varies by device and by whether offline language packs are
/// installed — it cannot be predicted from documentation.
abstract class SpeechToTextService {
  /// True only when a real engine is present AND permission is granted.
  bool get isAvailable;

  /// Shown to the user when [isAvailable] is false. Must be a plain sentence,
  /// never a technical error.
  String get unavailableReason;

  /// Whether this device's engine can handle a given language.
  Future<bool> supportsLanguage(AppLanguage language);

  /// Starts listening and completes with what was heard, or null.
  Future<String?> listen(AppLanguage language);

  Future<void> stop();
}

/// The only implementation today: none.
class UnavailableSpeechToText implements SpeechToTextService {
  const UnavailableSpeechToText();

  @override
  bool get isAvailable => false;

  @override
  String get unavailableReason =>
      'Voice input is not available yet. Please type your question.';

  @override
  Future<bool> supportsLanguage(AppLanguage language) async => false;

  @override
  Future<String?> listen(AppLanguage language) async => null;

  @override
  Future<void> stop() async {}
}

/// Reading text aloud.
///
/// INTERFACE ONLY, same position as [SpeechToTextService].
abstract class TextToSpeechService {
  bool get isAvailable;
  String get unavailableReason;

  Future<bool> supportsLanguage(AppLanguage language);

  /// Speaks [text] in [language]. Must do nothing (not throw) when
  /// unavailable, so callers never need to check first.
  Future<void> speak(String text, AppLanguage language);

  Future<void> stop();
}

class UnavailableTextToSpeech implements TextToSpeechService {
  const UnavailableTextToSpeech();

  @override
  bool get isAvailable => false;

  @override
  String get unavailableReason => 'Reading aloud is not available yet.';

  @override
  Future<bool> supportsLanguage(AppLanguage language) async => false;

  @override
  Future<void> speak(String text, AppLanguage language) async {}

  @override
  Future<void> stop() async {}
}

/// The commands the app will eventually understand.
///
/// Kept deliberately small. Unrestricted conversational control is far harder
/// to make reliable than seven fixed commands, and much worse for a user who
/// needs to know what will happen before they speak.
enum VoiceCommand { playGame, showMemories, readReminders, next, repeat, goBack, stop, unknown }

/// Turning recognised text into one of those commands.
///
/// This one is NOT blocked on hardware — it is plain string matching, and it
/// is implemented and tested below. It is the piece that will sit between
/// speech-to-text and the app once speech exists.
class VoiceCommandParser {
  const VoiceCommandParser();

  static const Map<VoiceCommand, List<String>> _phrases = {
    VoiceCommand.playGame: ['play a game', 'play game', 'start a game', 'play mindpal'],
    VoiceCommand.showMemories: ['show my memories', 'my memories', 'show memories', 'memory aid'],
    VoiceCommand.readReminders: ['read my reminders', 'my reminders', 'read reminders', 'what are my reminders'],
    VoiceCommand.next: ['next', 'next one', 'continue'],
    VoiceCommand.repeat: ['repeat', 'say again', 'say that again'],
    VoiceCommand.goBack: ['go back', 'back', 'previous'],
    VoiceCommand.stop: ['stop', 'cancel', 'quit'],
  };

  VoiceCommand parse(String spoken) {
    final cleaned = spoken
        .toLowerCase()
        .replaceAll(RegExp(r'[?!.,]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return VoiceCommand.unknown;

    // Exact match first: "back" should not be beaten by a longer phrase that
    // merely contains it.
    for (final entry in _phrases.entries) {
      if (entry.value.contains(cleaned)) return entry.key;
    }
    for (final entry in _phrases.entries) {
      for (final phrase in entry.value) {
        if (cleaned.contains(phrase)) return entry.key;
      }
    }
    return VoiceCommand.unknown;
  }
}
