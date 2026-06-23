import 'package:json_annotation/json_annotation.dart';

part 'notification_history_model.g.dart';

/// Supabase notification_history テーブル対応データモデル
/// 
/// 用途: アプリが受信した通知の履歴管理
/// - id: 通知ID（自動採番）
/// - user_id: ユーザーID（FK to auth.users）
/// - title: 通知タイトル
/// - body: 通知本文
/// - payload: JSON ペイロード（オプション）
/// - is_read: 既読フラグ
/// - received_at: 受信日時
/// - read_at: 既読日時
/// - created_at: レコード作成日時
@JsonSerializable()
class NotificationHistory {
  /// 通知ID（自動採番）
  final int id;

  /// ユーザーID
  final String userId;

  /// 通知タイトル
  final String title;

  /// 通知本文
  final String body;

  /// JSON ペイロード（任意）
  /// 例: {"scene": "友達", "level": "intermediate"}
  final String? payload;

  /// 既読フラグ
  final bool isRead;

  /// 受信日時（UTC）
  @JsonKey(name: 'received_at')
  final DateTime receivedAt;

  /// 既読日時（UTC）
  @JsonKey(name: 'read_at')
  final DateTime? readAt;

  /// レコード作成日時（UTC）
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  NotificationHistory({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.payload,
    this.isRead = false,
    required this.receivedAt,
    this.readAt,
    required this.createdAt,
  });

  /// JSON から NotificationHistory オブジェクトを生成
  factory NotificationHistory.fromJson(Map<String, dynamic> json) =>
      _$NotificationHistoryFromJson(json);

  /// NotificationHistory オブジェクトを JSON に変換
  Map<String, dynamic> toJson() => _$NotificationHistoryToJson(this);

  /// 既読マーク（readAt を現在時刻に設定）
  NotificationHistory markAsRead({DateTime? now}) {
    return NotificationHistory(
      id: id,
      userId: userId,
      title: title,
      body: body,
      payload: payload,
      isRead: true,
      receivedAt: receivedAt,
      readAt: now ?? DateTime.now().toUtc(),
      createdAt: createdAt,
    );
  }

  /// 通知受信からの経過時間（秒）
  int get secondsSinceReceived {
    return DateTime.now().toUtc().difference(receivedAt).inSeconds;
  }

  /// 通知受信からの経過時間（日本語表記）
  /// 例: "5分前", "2時間前", "3日前"
  String get relativeTime {
    final seconds = secondsSinceReceived;
    
    if (seconds < 60) return '今';
    if (seconds < 3600) return '${seconds ~/ 60}分前';
    if (seconds < 86400) return '${seconds ~/ 3600}時間前';
    if (seconds < 2592000) return '${seconds ~/ 86400}日前'; // 30日未満
    return '${seconds ~/ 2592000}ヶ月前';
  }

  @override
  String toString() => 'NotificationHistory('
      'id: $id, '
      'userId: $userId, '
      'title: $title, '
      'isRead: $isRead, '
      'receivedAt: $receivedAt)';
}
