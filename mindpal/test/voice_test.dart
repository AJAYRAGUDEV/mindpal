import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/services/voice_service.dart';

/// Voice logic that can be tested without a microphone.
///
/// What is NOT tested here, and cannot be on this machine: whether the device
/// actually hears anything, whether a voice exists for a language, and
/// whether the audio route behaves. Those need a real phone, and the
/// capability matrix says `untested` until someone has run them.
void main() {
  group('locale tags on the language list', () {
    test('every language either has a BCP-47 tag or says why not', () {
      for (final language in kAppLanguages) {
        final tag = language.speechLocaleTag;
        if (tag == null) {
          // No tag is a claim in itself: it means no standard code exists,
          // and the capability screen shows that to the user.
          expect(
            language.textToSpeech.isWorking,
            isFalse,
            reason: '${language.englishName} has no locale tag but claims '
                'text-to-speech works',
          );
          expect(language.speechToText.isWorking, isFalse);
          continue;
        }
        expect(
          RegExp(r'^[a-z]{2,3}(-[A-Za-z]{2,4})?$').hasMatch(tag),
          isTrue,
          reason: '${language.englishName} has a malformed tag: $tag',
        );
      }
    });

    test('no language claims speech it has not been shown to do', () {
      // Nothing has been run on a real device yet, so nothing may claim
      // verified. This test is what stops the claim creeping in later
      // without someone deliberately changing it here too.
      for (final language in kAppLanguages) {
        expect(
          language.speechToText,
          isNot(CapabilityStatus.verified),
          reason: '${language.englishName} claims verified speech input; '
              'that needs a real-device test first',
        );
        expect(
          language.textToSpeech,
          isNot(CapabilityStatus.verified),
          reason: '${language.englishName} claims verified speech output',
        );
      }
    });
  });

  group('VoiceCommandParser', () {
    const parser = VoiceCommandParser();

    test('recognises the fixed commands', () {
      expect(parser.parse('play a game'), VoiceCommand.playGame);
      expect(parser.parse('Show my memories'), VoiceCommand.showMemories);
      expect(parser.parse('read my reminders'), VoiceCommand.readReminders);
      expect(parser.parse('repeat'), VoiceCommand.repeat);
      expect(parser.parse('stop'), VoiceCommand.stop);
    });

    test('ignores punctuation and case', () {
      expect(parser.parse('  Play A Game!  '), VoiceCommand.playGame);
      expect(parser.parse('go back.'), VoiceCommand.goBack);
    });

    test('an exact short command is not beaten by a longer phrase', () {
      expect(parser.parse('back'), VoiceCommand.goBack);
    });

    test('anything else is unknown, never a guess', () {
      expect(parser.parse('who is my daughter'), VoiceCommand.unknown);
      expect(parser.parse(''), VoiceCommand.unknown);
      expect(parser.parse('   '), VoiceCommand.unknown);
    });
  });

  group('the unavailable implementations stay harmless', () {
    test('speech input reports unavailable without throwing', () async {
      const speech = UnavailableSpeechToText();
      expect(speech.isAvailable, isFalse);
      expect(speech.unavailableReason, isNotEmpty);
      expect(await speech.supportsLanguage(kEnglish), isFalse);
      expect(await speech.listen(kEnglish), isNull);
      await speech.stop();
    });

    test('speech output does nothing rather than failing', () async {
      const output = UnavailableTextToSpeech();
      expect(output.isAvailable, isFalse);
      expect(await output.supportsLanguage(kEnglish), isFalse);
      // Must not throw: callers are allowed to speak without checking first.
      await output.speak('anything', kEnglish);
      await output.stop();
    });
  });
}
