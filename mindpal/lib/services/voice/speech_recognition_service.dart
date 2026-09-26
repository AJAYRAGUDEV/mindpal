import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../l10n/app_language.dart';
import '../voice_service.dart';

/// What the microphone is doing right now, for the UI to draw.
enum ListeningState { idle, starting, listening, unavailable }

/// Speech to text through the device's own engine.
///
/// WHAT ACTUALLY RUNS. On Android this is the system speech recogniser
/// (usually Google's); in a browser it is the Web Speech API, which today
/// means Chrome and Edge and not Firefox or Safari. Neither is bundled with
/// the app, so what a given device can understand depends on that device —
/// which is why [supportedLanguages] asks the engine instead of assuming.
///
/// PRIVACY. Audio is captured only between [start] and [stop]/[cancel], and
/// nothing is recorded to disk at any point: the engine returns text and the
/// audio is discarded. The text, once the user has confirmed it, goes to our
/// own Express gateway — never the audio. Note honestly that Android's
/// recogniser and the browser's may themselves send audio to the OS vendor's
/// servers; that is the platform's behaviour, not something the app can
/// switch off, and the microphone explanation says so before asking.
class DeviceSpeechRecognition implements SpeechToTextService {
  DeviceSpeechRecognition();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialised = false;
  bool _initWorked = false;
  String _reason = 'Voice input has not been started yet.';

  /// The locale ids this device's engine reports, lower-cased for matching.
  List<String> _deviceLocales = const [];

  @override
  bool get isAvailable => _initWorked;

  @override
  String get unavailableReason => _reason;

  bool get isListening => _speech.isListening;

  /// Must be awaited once before anything else. Never throws.
  ///
  /// Returns false for the ordinary reasons — no engine, permission refused,
  /// a browser without the Web Speech API — and leaves [unavailableReason]
  /// set to something a user can act on.
  Future<bool> init({void Function(String status)? onStatus}) async {
    if (_initialised) return _initWorked;
    _initialised = true;

    try {
      _initWorked = await _speech.initialize(
        onError: (error) {
          // Logged, not shown: the UI decides what to say. The message is a
          // plugin string like 'error_no_match', useless to an elderly user.
          debugPrint('SPEECH: ${error.errorMsg} (permanent: ${error.permanent})');
        },
        onStatus: (status) {
          debugPrint('SPEECH: status $status');
          onStatus?.call(status);
        },
      );

      if (_initWorked) {
        final locales = await _speech.locales();
        _deviceLocales = [
          for (final locale in locales) locale.localeId.toLowerCase(),
        ];
        debugPrint('SPEECH: ready, ${_deviceLocales.length} locales offered');
      } else {
        _reason = kIsWeb
            ? 'This browser cannot listen. Chrome or Edge can, or you can '
                  'type your question.'
            : 'Voice input is not available on this device. Please type '
                  'your question.';
      }
    } catch (error) {
      _initWorked = false;
      _reason = 'Voice input could not start. Please type your question.';
      debugPrint('SPEECH: init failed: ${error.runtimeType}');
    }
    return _initWorked;
  }

  /// The subset of the app's languages this device can actually hear.
  ///
  /// Asked of the engine, never assumed. A language with no BCP-47 tag in
  /// [AppLanguage.speechLocaleTag] is excluded outright: there is no code to
  /// pass, so there is nothing to try.
  List<AppLanguage> supportedLanguages(List<AppLanguage> candidates) => [
    for (final language in candidates)
      if (_matchLocale(language) != null) language,
  ];

  @override
  Future<bool> supportsLanguage(AppLanguage language) async =>
      _initWorked && _matchLocale(language) != null;

  /// The device locale id to use for a language, or null if it has none.
  ///
  /// Matches exactly first ("as-in"), then on the language part alone
  /// ("as"), because a device may offer as_IN, as-IN or plain as. Region
  /// does not matter much for recognition but the tag has to be one the
  /// engine actually listed.
  String? _matchLocale(AppLanguage language) {
    final tag = language.speechLocaleTag;
    if (tag == null || _deviceLocales.isEmpty) return null;

    final wanted = tag.toLowerCase().replaceAll('-', '_');
    for (final locale in _deviceLocales) {
      if (locale.replaceAll('-', '_') == wanted) return locale;
    }

    final base = wanted.split('_').first;
    for (final locale in _deviceLocales) {
      if (locale.replaceAll('-', '_').split('_').first == base) return locale;
    }
    return null;
  }

  /// Starts listening. [onPartial] fires as words are recognised so the user
  /// can see it working; [onFinal] fires once with the finished text.
  ///
  /// The microphone stops on its own after [pauseFor] of silence, so a user
  /// who walks away does not leave it open.
  Future<bool> start({
    required AppLanguage language,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    void Function(double level)? onLevel,
  }) async {
    if (!_initWorked || _speech.isListening) return false;

    final localeId = _matchLocale(language);

    try {
      await _speech.listen(
        onSoundLevelChange: onLevel,
        onResult: (result) {
          final text = result.recognizedWords;
          if (result.finalResult) {
            onFinal(text);
          } else {
            onPartial(text);
          }
        },
        // Everything goes in listenOptions: the top-level localeId, pauseFor
        // and listenFor parameters are deprecated in speech_to_text 7.
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          // Sentences, not single commands: people dictate a whole reminder.
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          // Generous: an elderly user may pause mid-sentence to think.
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 45),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('SPEECH: listen failed: ${error.runtimeType}');
      return false;
    }
  }

  /// Ends listening and keeps whatever was heard.
  @override
  Future<void> stop() async {
    if (!_initWorked) return;
    try {
      await _speech.stop();
    } catch (_) {
      // Stopping an already-stopped recogniser is not an error worth raising.
    }
  }

  /// Ends listening and throws the result away.
  Future<void> cancel() async {
    if (!_initWorked) return;
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  /// Kept for the original interface. The screens use [start] instead,
  /// because a single-shot call cannot show partial words or be cancelled.
  @override
  Future<String?> listen(AppLanguage language) async {
    final completer = Completer<String?>();
    final started = await start(
      language: language,
      onPartial: (_) {},
      onFinal: (text) {
        if (!completer.isCompleted) completer.complete(text);
      },
    );
    if (!started) return null;
    return completer.future.timeout(
      const Duration(seconds: 50),
      onTimeout: () => null,
    );
  }
}
