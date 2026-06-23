import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_history_model.dart';

/// Supabase notification_history テーブル操作サービス
/// 
/// 機能:
/// - 通知履歴の保存（INSERT）
/// - 通知一覧の取得（SELECT + フィルタリング）
/// - 通知の既読マーク（UPDATE）
/// - 通知の削除（DELETE）
/// - RLS によるユーザー別アクセス制限
class NotificationHistoryService {
  static const String _tableName = 'notification_history';

  final SupabaseClient _supabase;

  NotificationHistoryService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// 現在のユーザーID を取得
  String? get _userId => _supabase.auth.currentUser?.id;

  /// 通知を保存（アプリが通知を受信したときに呼び出し）
  /// 
  /// [title] 通知タイトル
  /// [body] 通知本文
  /// [payload] JSON ペイロード（オプション）
  /// 
  /// 戻り値: 保存された通知オブジェクト
  /// 例外: ユーザー未認証、DB エラー
  Future<NotificationHistory> saveNotification({
    required String title,
    required String body,
    String? payload,
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
          'received_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        })
        .select()
        .single();

    return NotificationHistory.fromJson(response);
  }

  /// 通知一覧を取得
  /// 
  /// [isRead] true=既読のみ、false=未読のみ、null=全て
  /// [limit] 取得件数（デフォルト: 50）
  /// [offset] スキップ件数（ページング用）
  /// 
  /// 戻り値: NotificationHistory オブジェクトのリスト
  /// RLS により、現在のユーザーの通知のみ取得可能
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
        .order('received_at', ascending: false);

    // フィルタリング
    if (isRead != null) {
      query = query.eq('is_read', isRead);
    }

    // ページング
    query = query.range(offset, offset + limit - 1);

    final response = await query;

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
  /// 
  /// 戻り値: 更新件数
  Future<int> markMultipleAsRead(List<int> notificationIds) async {
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
        .inFilter('id', notificationIds)
        .eq('user_id', userId);

    return response;
  }

  /// 通知を削除
  /// 
  /// [notificationId] 通知ID
  /// 
  /// 戻り値: 削除件数（通常は 1）
  Future<int> deleteNotification(int notificationId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .delete()
        .eq('id', notificationId)
        .eq('user_id', userId);

    return response;
  }

  /// 複数の通知を削除
  /// 
  /// [notificationIds] 通知IDのリスト
  /// 
  /// 戻り値: 削除件数
  Future<int> deleteMultiple(List<int> notificationIds) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .delete()
        .inFilter('id', notificationIds)
        .eq('user_id', userId);

    return response;
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
        .eq('is_read', false)
        .count(CountOption.exact);

    return response.count;
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
  /// 戻り値: 削除件数
  /// 注意: RLS により、現在のユーザーの通知のみ削除
  Future<int> clearAllNotifications() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .delete()
        .eq('user_id', userId);

    return response;
  }

  /// リアルタイム通知リスナー（PostgreSQL LISTEN）
  /// 
  /// 用途: 新しい通知を受信したときにリアルタイムで UI を更新
  /// 
  /// 戻り値: Subscription オブジェクト（.unsubscribe() で停止可能）
  /// 
  /// 例：
  /// ```dart
  /// final subscription = notificationHistoryService.listenToNotifications((event) {
  ///   print('New notification: $event');
  ///   setState(() {
  ///     // UI を更新
  ///   });
  /// });
  /// 
  /// // クリーンアップ
  /// subscription.unsubscribe();
  /// ```
  RealtimeChannel listenToNotifications(
    Function(RealtimeMessage) onEvent,
  ) {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _supabase
        .realtime
        .channel('$_tableName:user_id=eq.$userId')
        .onPostgresChange(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tableName,
          filter: 'user_id=eq.$userId',
          callback: onEvent,
        )
        .subscribe();
  }
}
