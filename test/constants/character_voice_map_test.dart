import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/constants/character_voice_map.dart';

void main() {
  group('character_voice_map (T-35)', () {
    test('has a voice mapped for every scene id 1-18', () {
      for (var id = 1; id <= 18; id++) {
        final voice = voiceIdForScene(id.toString());
        expect(voice, isNotEmpty);
      }
    });

    test('falls back to defaultVoiceId for unknown scene ids', () {
      expect(voiceIdForScene('999'), defaultVoiceId);
    });
  });
}
