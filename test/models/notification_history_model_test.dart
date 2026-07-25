import 'package:flutter_test/flutter_test.dart';
import 'package:voikerchat/models/notification_history_model.dart';

void main() {
  group('NotificationHistory', () {
    // Supabaseから実際に返るスネークケースのJSON(user_id/is_read)。
    // 過去、Dartフィールド名(userId/isRead)のまま@JsonKeyが無く、
    // 実データを一度もパースできていなかった不具合の回帰テスト。
    final testJson = {
      'id': 1,
      'user_id': 'user-abc-123',
      'title': 'テストタイトル',
      'body': 'テスト本文',
      'payload': 'daily_reminder',
      'is_read': true,
      'status': 'scheduled',
      'received_at': '2026-07-25T08:00:00.000Z',
      'read_at': '2026-07-25T08:05:00.000Z',
      'created_at': '2026-07-25T07:00:00.000Z',
    };

    test('fromJson がスネークケースのuser_id/is_readを正しく読む', () {
      final model = NotificationHistory.fromJson(testJson);
      expect(model.id, 1);
      expect(model.userId, 'user-abc-123');
      expect(model.title, 'テストタイトル');
      expect(model.body, 'テスト本文');
      expect(model.payload, 'daily_reminder');
      expect(model.isRead, true);
      expect(model.status, NotificationHistoryStatus.scheduled);
      expect(model.receivedAt, DateTime.parse('2026-07-25T08:00:00.000Z'));
      expect(model.readAt, DateTime.parse('2026-07-25T08:05:00.000Z'));
    });

    test('status未指定のJSONはdeliveredにフォールバックする(既存行の後方互換)', () {
      final jsonWithoutStatus = Map<String, dynamic>.from(testJson)
        ..remove('status');
      final model = NotificationHistory.fromJson(jsonWithoutStatus);
      expect(model.status, NotificationHistoryStatus.delivered);
    });

    test('toJson がスネークケースのuser_id/is_read/statusで出力する', () {
      final model = NotificationHistory(
        id: 1,
        userId: 'user-abc-123',
        title: 'テストタイトル',
        body: 'テスト本文',
        status: NotificationHistoryStatus.scheduled,
        receivedAt: DateTime.parse('2026-07-25T08:00:00.000Z'),
        createdAt: DateTime.parse('2026-07-25T07:00:00.000Z'),
      );
      final json = model.toJson();
      expect(json['user_id'], 'user-abc-123');
      expect(json['is_read'], false);
      expect(json['status'], 'scheduled');
    });

    test('markAsRead はstatusを保持したままreadAtを更新する', () {
      final model = NotificationHistory.fromJson(testJson);
      final now = DateTime.parse('2026-07-25T09:00:00.000Z');
      final updated = model.markAsRead(now: now);
      expect(updated.status, NotificationHistoryStatus.scheduled);
      expect(updated.isRead, true);
      expect(updated.readAt, now);
    });
  });
}
