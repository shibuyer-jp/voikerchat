import 'package:json_annotation/json_annotation.dart';

part 'notification_history_model.g.dart';

/// 通知履歴のステータス。
/// - scheduled: ローカル通知(毎日リマインダー/プレミアム勧導)をOS側に
///   先行予約した時点の状態。received_atは予定発火時刻(未来)。
/// - delivered: 実際に届いた(または届いたとみなせる)状態。マイルストーン/
///   機能更新/リモートプッシュは表示・受信のその場でdeliveredとして書き込み、
///   scheduledは次回起動時のリコンサイルでdeliveredへ更新される。
enum NotificationHistoryStatus {
  scheduled,
  delivered;

  String get value => name;

  static NotificationHistoryStatus fromValue(String value) {
    return NotificationHistoryStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => NotificationHistoryStatus.delivered,
    );
  }
}

/// Supabase notification_history テーブル対応データモデル
///
/// 用途: アプリが受信した通知の履歴管理
/// - id: 通知ID（自動採番）
/// - user_id: ユーザーID（FK to auth.users）
/// - title: 通知タイトル
/// - body: 通知本文
/// - payload: JSON ペイロード（オプション）
/// - is_read: 既読フラグ
/// - status: scheduled/delivered（2026-07-25追加、案B）
/// - received_at: 受信日時（statusがscheduledの間は予定発火時刻）
/// - read_at: 既読日時
/// - created_at: レコード作成日時
@JsonSerializable()
class NotificationHistory {
  /// 通知ID（自動採番）
  final int id;

  /// ユーザーID
  @JsonKey(name: 'user_id')
  final String userId;

  /// 通知タイトル
  final String title;

  /// 通知本文
  final String body;

  /// JSON ペイロード（任意）
  /// 例: {"scene": "友達", "level": "intermediate"}
  final String? payload;

  /// 既読フラグ
  @JsonKey(name: 'is_read')
  final bool isRead;

  /// 配信ステータス（scheduled/delivered）。DB側はTEXT("scheduled"/"delivered")。
  @JsonKey(
    fromJson: _statusFromJson,
    toJson: _statusToJson,
    defaultValue: NotificationHistoryStatus.delivered,
  )
  final NotificationHistoryStatus status;

  /// 受信日時（UTC）。status=scheduledの間は予定発火時刻。
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
    this.status = NotificationHistoryStatus.delivered,
    required this.receivedAt,
    this.readAt,
    required this.createdAt,
  });

  static NotificationHistoryStatus _statusFromJson(String value) =>
      NotificationHistoryStatus.fromValue(value);

  static String _statusToJson(NotificationHistoryStatus status) =>
      status.value;

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
      status: status,
      receivedAt: receivedAt,
      readAt: now ?? DateTime.now().toUtc(),
      createdAt: createdAt,
    );
  }

  /// 通知受信からの経過時間（秒）
  int get secondsSinceReceived {
    return DateTime.now().toUtc().difference(receivedAt).inSeconds;
  }

  @override
  String toString() => 'NotificationHistory('
      'id: $id, '
      'userId: $userId, '
      'title: $title, '
      'isRead: $isRead, '
      'status: ${status.value}, '
      'receivedAt: $receivedAt)';
}
