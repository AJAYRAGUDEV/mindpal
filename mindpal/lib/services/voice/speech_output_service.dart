import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../l10n/app_language.dart';
import '../voice_service.dart';

/// What the speaker is doing, for the Play / Pause / Stop controls.
enum SpeakingState { idle, speaking, paused }

/// Reading answers aloud through the device's own voices.
///
/// As with recognition, the voices belong to the device, not to this app: an
/// Android phone speaks the languages whose TTS data is installed, and a
/// browser speaks whatever its OS provides. So [supportedLanguages] asks the
/// engine rather than assuming, and a language the engine does not have is
/// reported as unsupported instead of being read aloud in the wrong accent.
///
/// ONE VOICE AT A TIME. Every [speak] stops whatever is already speaking
/// first. Two overlapping voices are unintelligible, and for a user with
/// memory difficulty they are worse than silence.
class DeviceSpeechOutput implements TextToSpeechService {
  DeviceSpeechOutput();

  final FlutterTts _tts = FlutterTts();

  bool _initialised = false;
  bool _initWorked = false;
  String _reason = 'Reading aloud has not been started yet.';

  /// Lower-cased language tags the engine reports it can speak.
  List<String> _engineLanguages = const [];

  SpeakingState _state = SpeakingState.idle;
  SpeakingState get state => _state;

  /// The text of the last thing spoken, so Replay needs no arguments.
  String? _lastText;
  AppLanguage? _lastLanguage;

  bool get canReplay => _lastText != null;

  /// Notifies the UI when speaking starts, pauses, finishes or fails.
  final _stateController = StreamController<SpeakingState>.broadcast();
  Stream<SpeakingState> get stateChanges => _stateController.stream;

  @override
  bool get isAvailable => _initWorked;

  @override
  String get unavailableReason => _reason;

  Future<bool> init() async {
    if (_initialised) return _initWorked;
    _initialised = true;

    try {
      final languages = await _tts.getLanguages;
      _engineLanguages = [
        if (languages is List)
          for (final language in languages) '$language'.toLowerCase(),
      ];

      // Slower than default. These answers are read by someone who may be
      // hard of hearing and is not in a hurry.
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1);
      await _tts.setPitch(1);

      _tts.setStartHandler(() => _setState(SpeakingState.speaking));
      _tts.setCompletionHandler(() => _setState(SpeakingState.idle));
      _tts.setCancelHandler(() => _setState(SpeakingState.idle));
      _tts.setPauseHandler(() => _setState(SpeakingState.paused));
      _tts.setContinueHandler(() => _setState(SpeakingState.speaking));
      _tts.setErrorHandler((message) {
        debugPrint('TTS: $message');
        _setState(SpeakingState.idle);
      });

      _initWorked = _engineLanguages.isNotEmpty;
      if (!_initWorked) {
        _reason = 'This device has no voices installed, so answers cannot be '
            'read aloud.';
      }
      debugPrint('TTS: ready, ${_engineLanguages.length} voices offered');
    } catch (error) {
      _initWorked = false;
      _reason = 'Reading aloud is not available on this device.';
      debugPrint('TTS: init failed: ${error.runtimeType}');
    }
    return _initWorked;
  }

  void _setState(SpeakingState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  List<AppLanguage> supportedLanguages(List<AppLanguage> candidates) => [
    for (final language in candidates)
      if (_matchLanguage(language) != null) language,
  ];

  @override
  Future<bool> supportsLanguage(AppLanguage language) async =>
      _initWorked && _matchLanguage(language) != null;

  /// The engine tag for a language, or null. Same two-step match as
  /// recognition: exact tag first, then the language part alone.
  String? _matchLanguage(AppLanguage language) {
    final tag = language.speechLocaleTag;
    if (tag == null || _engineLanguages.isEmpty) return null;

    final wanted = tag.toLowerCase().replaceAll('_', '-');
    for (final available in _engineLanguages) {
      if (available.replaceAll('_', '-') == wanted) return available;
    }

    final base = wanted.split('-').first;
    for (final available in _engineLanguages) {
      if (available.replaceAll('_', '-').split('-').first == base) {
        return available;
      }
    }
    return null;
  }

  @override
  Future<void> speak(String text, AppLanguage language) async {
    if (!_initWorked || text.trim().isEmpty) return;

    // Never two voices at once.
    await stop();

    final tag = _matchLanguage(language);
    if (tag == null) {
      // No voice for this language. Saying it in an English voice would be
      // unintelligible, so say nothing and let the UI explain.
      debugPrint('TTS: no voice for ${language.code}; not speaking');
      return;
    }

    _lastText = text;
    _lastLanguage = language;

    try {
      await _tts.setLanguage(tag);
      await _tts.speak(text);
    } catch (error) {
      debugPrint('TTS: speak failed: ${error.runtimeType}');
      _setState(SpeakingState.idle);
    }
  }

  Future<void> pause() async {
    if (!_initWorked || _state != SpeakingState.speaking) return;
    try {
      await _tts.pause();
    } catch (_) {}
  }

  /// Resumes a paused reading, or replays the last one if it had finished.
  ///
  /// flutter_tts has no universal "resume", so a paused reading is restarted
  /// from the beginning. For a two-sentence answer that is the right
  /// trade — an elderly user who pressed pause wants to hear it again
  /// anyway, and a half-sentence resume is more confusing than a restart.
  Future<void> resume() async {
    if (!_initWorked) return;
    await replay();
  }

  Future<void> replay() async {
    final text = _lastText;
    final language = _lastLanguage;
    if (text == null || language == null) return;
    await speak(text, language);
  }

  @override
  Future<void> stop() async {
    if (!_initWorked) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _setState(SpeakingState.idle);
  }

  void dispose() {
    unawaited(stop());
    _stateController.close();
  }
}
