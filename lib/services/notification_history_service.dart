import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voikerchat/models/notification_history_model.dart';

/// Supabase notification_history テーブル操作サービス
/// 
/// 機能:
/// - 通知履歴の保存（INSERT）
/// - 通知一覧の取得（SELECT + フィルタリング）
/// - 通知の既読マーク（UPDATE）
/// - 通知の削除（DELETE）
/// - RLS によるユーザー別アクセス制限
class NotificationHistoryService {
  final logger = Logger('NotificationHistoryService');

  static const String _tableName = 'notification_history';

  final SupabaseClient _supabase;

  NotificationHistoryService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// 現在のユーザーID を取得
  String? get _userId => _supabase.auth.currentUser?.id;

  /// 通知を保存
  ///
  /// [title] 通知タイトル
  /// [body] 通知本文
  /// [payload] JSON ペイロード（オプション）
  /// [status] delivered=表示・受信のその場で呼ぶ（デフォルト）。
  ///   scheduled=zonedSchedule等でOS側に先行予約した時点で呼ぶ（案B）。
  /// [receivedAt] 省略時は現在時刻(UTC)。status=scheduledの場合は
  ///   予定発火時刻を渡すこと。
  ///
  /// 戻り値: 保存された通知オブジェクト
  /// 例外: ユーザー未認証、DB エラー
  Future<NotificationHistory> saveNotification({
    required String title,
    required String body,
    String? payload,
    NotificationHistoryStatus status = NotificationHistoryStatus.delivered,
    DateTime? receivedAt,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now().toUtc();

    final response = await _supabase
        .from(_tableName)
        .insert({
          'user_id': userId,
          'title': title,
          'body': body,
          'payload': payload,
          'is_read': false,
          'status': status.value,
          'received_at': (receivedAt ?? now).toUtc().toIso8601String(),
          'created_at': now.toIso8601String(),
        })
        .select()
        .single();

    return NotificationHistory.fromJson(response);
  }

  /// status='scheduled' で既に同じ内容の履歴が予約済みかどうかを確認する。
  /// 同一 payload・同一 received_at（予定発火時刻）のscheduled行が既に
  /// あれば true。毎起動時の再スケジュールで重複INSERTしないためのガード。
  Future<bool> hasScheduledEntry({
    required String payload,
    required DateTime receivedAt,
  }) async {
    final userId = _userId;
    if (userId == null) return false;

    final response = await _supabase
        .from(_tableName)
        .select('id')
        .eq('user_id', userId)
        .eq('payload', payload)
        .eq('status', NotificationHistoryStatus.scheduled.value)
        .eq('received_at', receivedAt.toUtc().toIso8601String())
        .limit(1);

    return (response as List).isNotEmpty;
  }

  /// 予定時刻(received_at)を過ぎた scheduled 状態の履歴を delivered へ
  /// 一括更新する（案B: アプリ起動時のリコンサイル）。
  /// OSのローカル通知配信はほぼ確実に成功するため、時刻が過ぎていれば
  /// 「届いた」とみなす。
  Future<void> reconcileScheduledNotifications() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _supabase
          .from(_tableName)
          .update({'status': NotificationHistoryStatus.delivered.value})
          .eq('user_id', userId)
          .eq('status', NotificationHistoryStatus.scheduled.value)
          .lte('received_at', DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      logger.warning(
          '[NotificationHistoryService] reconcileScheduledNotifications failed: $e');
    }
  }

  /// 指定payloadの未発火(scheduled)予約を取り消す。通知そのものを
  /// キャンセルする際（例: 通知OFF切り替え時）に、後のreconcileで
  /// 誤ってdeliveredにされないよう対で呼ぶこと。
  Future<void> cancelScheduledByPayload(String payload) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .eq('payload', payload)
          .eq('status', NotificationHistoryStatus.scheduled.value);
    } catch (e) {
      logger.warning(
          '[NotificationHistoryService] cancelScheduledByPayload failed: $e');
    }
  }

  /// 通知一覧を取得
  ///
  /// [isRead] true=既読のみ、false=未読のみ、null=全て
  /// [limit] 取得件数（デフォルト: 50）
  /// [offset] スキップ件数（ページング用）
  ///
  /// 戻り値: NotificationHistory オブジェクトのリスト
  /// RLS により、現在のユーザーの通知のみ取得可能
  /// status='scheduled'（未配信・予定時刻が未来）の行は対象外。
  /// 画面に出さないことで、誤既読・誤削除・削除後の「復活に見える」
  /// 挙動を防ぐ（2026-07-31調査、案C-①）。
  Future<List<NotificationHistory>> getHistory({
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    var query = _supabase
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .eq('status', NotificationHistoryStatus.delivered.value);

    // フィルタリング
    if (isRead != null) {
      query = query.eq('is_read', isRead);
    }

    // 順序付けとページング（チェーンで続ける）
    final response = await query
        .order('received_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => NotificationHistory.fromJson(json))
        .toList();
  }

  /// 通知を既読マーク
  /// 
  /// [notificationId] 通知ID
  /// 
  /// 戻り値: 更新された通知オブジェクト
  Future<NotificationHistory> markAsRead(int notificationId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now().toUtc();

    final response = await _supabase
        .from(_tableName)
        .update({
          'is_read': true,
          'read_at': now.toIso8601String(),
        })
        .eq('id', notificationId)
        .eq('user_id', userId)
        .select()
        .single();

    return NotificationHistory.fromJson(response);
  }

  /// 複数の通知を既読マーク
  ///
  /// [notificationIds] 通知IDのリスト
  Future<void> markMultipleAsRead(List<int> notificationIds) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now().toUtc();

    // 複数ID の IN フィルタリング（v1.10 互換）
    var query = _supabase
        .from(_tableName)
        .update({
          'is_read': true,
          'read_at': now.toIso8601String(),
        })
        .eq('user_id', userId);

    // 各ID に対して OR フィルタリング
    for (final id in notificationIds) {
      query = query.or('id.eq.$id');
    }

    await query;
  }

  /// 通知を削除
  ///
  /// [notificationId] 通知ID
  ///
  /// 戻り値: 実際に削除された件数（0=対象が既に存在しなかった、1=成功）。
  /// .select() で削除された行を返させることで、削除の成否を
  /// 呼び出し側が判定できるようにする（2026-07-31調査、案B）。
  Future<int> deleteNotification(int notificationId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .delete()
        .eq('id', notificationId)
        .eq('user_id', userId)
        .select('id');

    return (response as List).length;
  }

  /// 複数の通知を削除
  ///
  /// [notificationIds] 通知IDのリスト
  Future<void> deleteMultiple(List<int> notificationIds) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // 複数ID の OR フィルタリング（v1.10 互換）
    var query = _supabase
        .from(_tableName)
        .delete()
        .eq('user_id', userId);

    for (final id in notificationIds) {
      query = query.or('id.eq.$id');
    }

    await query;
  }

  /// 未読通知件数を取得
  /// 
  /// 戻り値: 未読通知数
  Future<int> getUnreadCount() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  /// 日付範囲で通知を検索
  /// 
  /// [startDate] 開始日時（UTC）
  /// [endDate] 終了日時（UTC）
  /// 
  /// 戻り値: 該当する通知リスト
  Future<List<NotificationHistory>> getHistoryByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .gte('received_at', startDate.toIso8601String())
        .lte('received_at', endDate.toIso8601String())
        .order('received_at', ascending: false);

    return (response as List)
        .map((json) => NotificationHistory.fromJson(json))
        .toList();
  }

  /// すべての通知を削除（危険操作）
  ///
  /// 注意: RLS により、現在のユーザーの通知のみ削除
  Future<void> clearAllNotifications() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _supabase
        .from(_tableName)
        .delete()
        .eq('user_id', userId);
  }

  /// リアルタイム通知リスナー（Supabase Realtime）
  /// 
  /// 注意: v1.10 では API が異なるため、実装は後回しにします
  /// 用途: 新しい通知を受信したときにリアルタイムで UI を更新
  /// 
  /// TODO: Supabase Realtime API v2 対応後に実装
  void listenToNotifications(Function(dynamic) onEvent) {
    logger.info('Realtime listener: Implementation pending for Supabase v2.x');
    // v1.10 では複雑なため、一旦スキップ
    // v2.x では以下のように実装予定:
    // _supabase
    //     .realtime
    //     .channel('$_tableName:user_id=eq.$userId')
    //     .onPostgresChange(...)
    //     .subscribe();
  }
}
