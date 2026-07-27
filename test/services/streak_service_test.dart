import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/services/streak_service.dart';

void main() {
  group('StreakService.evaluateGap (Build 13, 案A)', () {
    late StreakService service;

    setUp(() {
      // シングルトンだが nowProvider は差し替え可能(Build 13でテスト用に追加)。
      service = StreakService();
    });

    test('前回学習日が今日なら "today"', () {
      service.nowProvider = () => DateTime(2026, 7, 27, 10, 0);
      expect(service.evaluateGap('2026-07-27'), 'today');
    });

    test('前回学習日が昨日なら "continuing"', () {
      service.nowProvider = () => DateTime(2026, 7, 27, 10, 0);
      expect(service.evaluateGap('2026-07-26'), 'continuing');
    });

    test('前回学習日が一昨日なら "broken"', () {
      service.nowProvider = () => DateTime(2026, 7, 27, 10, 0);
      expect(service.evaluateGap('2026-07-25'), 'broken');
    });

    test('前回学習日がずっと前でも "broken"', () {
      service.nowProvider = () => DateTime(2026, 7, 27, 10, 0);
      expect(service.evaluateGap('2026-01-01'), 'broken');
    });

    test('前回学習記録が無い(null)なら "broken"', () {
      service.nowProvider = () => DateTime(2026, 7, 27, 10, 0);
      expect(service.evaluateGap(null), 'broken');
    });

    test('月またぎでも正しく昨日/一昨日を判定する(8/1 → 7/31)', () {
      service.nowProvider = () => DateTime(2026, 8, 1, 0, 30);
      expect(service.evaluateGap('2026-07-31'), 'continuing');
      expect(service.evaluateGap('2026-07-30'), 'broken');
    });

    test('年またぎでも正しく判定する(1/1 → 前年12/31)', () {
      service.nowProvider = () => DateTime(2027, 1, 1, 0, 30);
      expect(service.evaluateGap('2026-12-31'), 'continuing');
      expect(service.evaluateGap('2026-12-30'), 'broken');
    });

    test(
        '時刻に関わらず暦日のみで判定する(23:59と00:01でも同じ「今日」の判定にならない場合の境界確認)',
        () {
      // 前日23:59に学習し、当日00:01に再度開いた場合 → 暦日としては
      // 「昨日→今日」の1日差であり continuing 扱いになるべき(UTC基準の
      // ときに問題だった「同日扱いされない」ケースの逆、ローカル基準では
      // 正しく1日分の差として継続扱いになることを確認)。
      service.nowProvider = () => DateTime(2026, 7, 27, 0, 1);
      expect(service.evaluateGap('2026-07-26'), 'continuing');
    });
  });

  group('StreakService.localDateString', () {
    test('ローカルタイムの暦日を YYYY-MM-DD 形式に変換する', () {
      final service = StreakService();
      expect(
        service.localDateString(DateTime(2026, 7, 5, 23, 59)),
        '2026-07-05',
      );
      expect(
        service.localDateString(DateTime(2026, 12, 31, 0, 0)),
        '2026-12-31',
      );
    });
  });
}
