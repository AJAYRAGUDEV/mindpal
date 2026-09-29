import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_language.dart';
import 'speech_output_service.dart';
import 'speech_recognition_service.dart';

/// Why voice is not offered, in words a user can act on.
enum VoiceBlock {
  none,
  noEngine,
  permissionDenied,
  languageUnsupported,
}

/// Holds the microphone and the speaker for the whole app.
///
/// One instance, created in main() and passed down, for a reason that matters
/// on a phone: a second recogniser or a second voice would fight the first
/// for the audio device, and the symptom is silence rather than an error.
/// Everything that listens or speaks goes through here.
///
/// It owns no UI. Screens watch [changes] and draw whatever state it reports.
class VoiceController extends ChangeNotifier {
  VoiceController({
    DeviceSpeechRecognition? recognition,
    DeviceSpeechOutput? output,
  }) : _recognition = recognition ?? DeviceSpeechRecognition(),
       _output = output ?? DeviceSpeechOutput();

  final DeviceSpeechRecognition _recognition;
  final DeviceSpeechOutput _output;

  StreamSubscription<SpeakingState>? _speakingSub;

  bool _ready = false;
  bool get isReady => _ready;

  ListeningState _listening = ListeningState.idle;
  ListeningState get listening => _listening;

  /// What has been heard so far this session. Editable by the user before it
  /// is sent — recognition is wrong often enough that sending it unseen
  /// would be the single most annoying thing this feature could do.
  String _heard = '';
  String get heard => _heard;

  double _level = 0;

  /// 0..1, for the listening indicator. Purely cosmetic, but it is the only
  /// way a user can tell the microphone is hearing them at all.
  double get soundLevel => _level;

  SpeakingState get speaking => _output.state;
  bool get canReplay => _output.canReplay;

  /// Whether answers are read aloud automatically. The user can switch this
  /// off and still use Play on individual answers.
  bool _autoSpeak = true;
  bool get autoSpeak => _autoSpeak;
  set autoSpeak(bool value) {
    _autoSpeak = value;
    if (!value) unawaited(stopSpeaking());
    notifyListeners();
  }

  bool get micAvailable => _recognition.isAvailable;
  bool get speakerAvailable => _output.isAvailable;

  String get micUnavailableReason => _recognition.unavailableReason;
  String get speakerUnavailableReason => _output.unavailableReason;

  /// Started once, at app launch, and never throws.
  ///
  /// Deliberately does NOT ask for the microphone here. Permission is
  /// requested the first time the user taps the microphone button, with an
  /// explanation — asking at launch, before they know what the app does,
  /// earns a reflexive refusal that is then awkward to undo.
  Future<void> init() async {
    if (_ready) return;
    await _recognition.init(
      onStatus: (status) {
        // The engine stops by itself after silence. Reflect that rather than
        // leaving the UI claiming it is still listening.
        if (status == 'done' || status == 'notListening') {
          if (_listening == ListeningState.listening) {
            _listening = ListeningState.idle;
            _level = 0;
            notifyListeners();
          }
        }
      },
    );
    await _output.init();

    _speakingSub = _output.stateChanges.listen((_) => notifyListeners());
    _ready = true;
    notifyListeners();
  }

  /// The app languages this device can hear, and speak, respectively.
  /// Measured from the engines, never assumed.
  List<AppLanguage> recognisableLanguages() =>
      _recognition.supportedLanguages(kAppLanguages);

  List<AppLanguage> speakableLanguages() =>
      _output.supportedLanguages(kAppLanguages);

  /// The voices this device can read [language] with. Often empty, and that is
  /// a fact about the phone rather than a fault.
  List<DeviceVoice> voicesFor(AppLanguage language) =>
      _output.voicesFor(language);

  DeviceVoice? get chosenVoice => _output.chosenVoice;

  /// Switches voice. Notifies, so a chooser can show the new selection.
  Future<void> useVoice(DeviceVoice? voice) async {
    await _output.useVoice(voice);
    notifyListeners();
  }

  Future<bool> canHear(AppLanguage language) =>
      _recognition.supportsLanguage(language);

  Future<bool> canSpeak(AppLanguage language) =>
      _output.supportsLanguage(language);

  /// Why voice input is blocked for this language, if it is.
  Future<VoiceBlock> checkMic(AppLanguage language) async {
    if (!_recognition.isAvailable) return VoiceBlock.noEngine;
    if (!await _recognition.supportsLanguage(language)) {
      return VoiceBlock.languageUnsupported;
    }
    return VoiceBlock.none;
  }

  // ----------------------------------------------------------- listening

  /// Starts listening. Speaking stops first: the microphone must never hear
  /// the app's own voice and transcribe it.
  Future<bool> startListening(AppLanguage language) async {
    if (!_recognition.isAvailable || _listening != ListeningState.idle) {
      return false;
    }

    await stopSpeaking();

    _heard = '';
    _level = 0;
    _listening = ListeningState.starting;
    notifyListeners();

    final started = await _recognition.start(
      language: language,
      onPartial: (text) {
        _heard = text;
        if (_listening != ListeningState.listening) {
          _listening = ListeningState.listening;
        }
        notifyListeners();
      },
      onFinal: (text) {
        _heard = text;
        _listening = ListeningState.idle;
        _level = 0;
        notifyListeners();
      },
      onLevel: (level) {
        // The plugin's scale differs by platform; clamp to something a bar
        // can use rather than pretending it is calibrated.
        _level = (level.abs() / 10).clamp(0.0, 1.0);
        notifyListeners();
      },
    );

    if (!started) {
      _listening = ListeningState.idle;
      notifyListeners();
      return false;
    }

    _listening = ListeningState.listening;
    notifyListeners();
    return true;
  }

  /// Stop and keep what was heard.
  Future<void> stopListening() async {
    if (_listening == ListeningState.idle) return;
    await _recognition.stop();
    _listening = ListeningState.idle;
    _level = 0;
    notifyListeners();
  }

  /// Stop and throw away what was heard.
  Future<void> cancelListening() async {
    await _recognition.cancel();
    _heard = '';
    _listening = ListeningState.idle;
    _level = 0;
    notifyListeners();
  }

  void clearHeard() {
    _heard = '';
    notifyListeners();
  }

  // ------------------------------------------------------------ speaking

  /// Reads [text] aloud if the user has automatic speech on.
  Future<void> speakIfEnabled(String text, AppLanguage language) async {
    if (!_autoSpeak) return;
    await speak(text, language);
  }

  /// Reads [text] aloud regardless of the automatic setting — this is what
  /// the Play button calls.
  Future<void> speak(String text, AppLanguage language) async {
    if (!_output.isAvailable) return;
    // Never speak over the microphone.
    if (_listening != ListeningState.idle) await stopListening();
    await _output.speak(text, language);
  }

  Future<void> pauseSpeaking() => _output.pause();
  Future<void> resumeSpeaking() => _output.resume();
  Future<void> replay() => _output.replay();
  Future<void> stopSpeaking() => _output.stop();

  @override
  void dispose() {
    _speakingSub?.cancel();
    unawaited(_recognition.cancel());
    _output.dispose();
    super.dispose();
  }
}
