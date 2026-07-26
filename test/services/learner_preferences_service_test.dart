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

    test('recent scene ids default to empty list', () async {
      final service = LearnerPreferencesService();
      expect(await service.getRecentSceneIds(), isEmpty);
    });

    test('recent scene ids are ordered most-recent-first', () async {
      final service = LearnerPreferencesService();
      await service.recordRecentSceneId('1');
      await service.recordRecentSceneId('2');
      await service.recordRecentSceneId('3');

      expect(await service.getRecentSceneIds(), ['3', '2', '1']);
    });

    test('recording an existing id moves it to the front instead of duplicating', () async {
      final service = LearnerPreferencesService();
      await service.recordRecentSceneId('1');
      await service.recordRecentSceneId('2');
      await service.recordRecentSceneId('1');

      expect(await service.getRecentSceneIds(), ['1', '2']);
    });

    test('recent scene ids are capped at 3, dropping the oldest', () async {
      final service = LearnerPreferencesService();
      await service.recordRecentSceneId('1');
      await service.recordRecentSceneId('2');
      await service.recordRecentSceneId('3');
      await service.recordRecentSceneId('4');

      expect(await service.getRecentSceneIds(), ['4', '3', '2']);
    });
  });
}
