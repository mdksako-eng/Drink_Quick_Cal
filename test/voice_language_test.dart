// test/voice_language_test.dart
// The spoken language must follow the APP language until the user picks one.
//
// It did not: the fallback was a hardcoded 'en-US', so a French shop that never opened
// the voice settings heard its French replies read aloud in an English voice. The stored
// choice always wins — the app language only decides *before* that choice exists.
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_calculator_fixed/services/voice_service.dart';

void main() {
  group('VoiceService.resolveTtsLanguage', () {
    test('no stored choice + a French app speaks French', () {
      expect(
        VoiceService.resolveTtsLanguage(stored: null, appLanguage: 'fr'),
        'fr-FR',
      );
    });

    test('no stored choice + an English app speaks English', () {
      expect(
        VoiceService.resolveTtsLanguage(stored: null, appLanguage: 'en'),
        'en-US',
      );
    });

    test('a stored choice beats the app language, either way round', () {
      // A French shop that deliberately chose English keeps English, and vice versa.
      expect(
        VoiceService.resolveTtsLanguage(stored: 'fr-FR', appLanguage: 'en'),
        'fr-FR',
      );
      expect(
        VoiceService.resolveTtsLanguage(stored: 'en-US', appLanguage: 'fr'),
        'en-US',
      );
    });

    test('a blank stored value counts as no choice at all', () {
      // A blank is what an interrupted first run can leave behind; it must not freeze the
      // voice on English.
      expect(
        VoiceService.resolveTtsLanguage(stored: '', appLanguage: 'fr'),
        'fr-FR',
      );
      expect(
        VoiceService.resolveTtsLanguage(stored: '   ', appLanguage: 'fr'),
        'fr-FR',
      );
    });

    test('a bare language code is normalised to a full TTS locale', () {
      expect(
        VoiceService.resolveTtsLanguage(stored: 'fr', appLanguage: 'en'),
        'fr-FR',
      );
      expect(
        VoiceService.resolveTtsLanguage(stored: 'EN', appLanguage: 'fr'),
        'en-US',
      );
    });

    test('an unexpected app language falls back to English, never to nothing', () {
      // localesFor() is the single mapping; anything not French is English.
      expect(
        VoiceService.resolveTtsLanguage(stored: null, appLanguage: 'de'),
        'en-US',
      );
    });
  });
}
