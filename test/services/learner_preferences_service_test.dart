import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voikerchat/services/learner_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LearnerPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('difficulty feedback defaults to null and round-trips', () async {
      final service = LearnerPreferencesService();
      expect(await service.getDifficultyFeedback(), isNull);

      await service.setDifficultyFeedback('hard');
      expect(await service.getDifficultyFeedback(), 'hard');

      await service.setDifficultyFeedback('easy');
      expect(await service.getDifficultyFeedback(), 'easy');
    });

    test('last scene id defaults to null and round-trips', () async {
      final service = LearnerPreferencesService();
      expect(await service.getLastSceneId(), isNull);

      await service.setLastSceneId('14');
      expect(await service.getLastSceneId(), '14');
    });

    test('furigana defaults to true (existing behavior unchanged)', () async {
      final service = LearnerPreferencesService();
      expect(await service.isFuriganaEnabled(), isTrue);
    });
  });
}
