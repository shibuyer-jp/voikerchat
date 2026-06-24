/// NotificationDataModel
/// Firebase Cloud Messaging のペイロード構造を定義
class NotificationDataModel {
  final String id;
  final String type; // 'daily_reminder', 'milestone', 'premium_upsell', 'feature_update'
  final String title;
  final String body;
  final String? imageUrl;
  final String? conversationId; // パターンB: 会話ID（通知タップ時に使用）
  final Map<String, String>? customData;
  final DateTime createdAt;
  final bool isRead;

  NotificationDataModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.conversationId,
    this.customData,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// JSON → NotificationDataModel に変換
  factory NotificationDataModel.fromJson(Map<String, dynamic> json) {
    return NotificationDataModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      conversationId: json['conversationId'] as String?,
      customData: json['customData'] != null
          ? Map<String, String>.from(json['customData'] as Map)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// Firebase RemoteMessage ペイロードから変換
  factory NotificationDataModel.fromFirebaseMap(Map<String, dynamic> data) {
    // 既知キーを除外したカスタムデータを作成
    final Map<String, dynamic> customData = {};
    const excludeKeys = {
      'notification_id',
      'notification_type',
      'title',
      'body',
      'image_url',
      'conversation_id', // conversationId は専用フィールドに格納
    };
    
    data.forEach((key, value) {
      if (!excludeKeys.contains(key) && value != null) {
        customData[key] = value;
      }
    });

    return NotificationDataModel(
      id: data['notification_id'] as String? ?? '',
      type: data['notification_type'] as String? ?? 'unknown',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageUrl: data['image_url'] as String?,
      conversationId: data['conversation_id'] as String?,
      customData: customData.isEmpty ? null : Map<String, String>.from(
        customData.map((k, v) => MapEntry(k, v.toString()))
      ),
    );
  }

  /// NotificationDataModel → JSON に変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'conversationId': conversationId,
      'customData': customData,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  /// 既読状態を更新
  NotificationDataModel copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? imageUrl,
    String? conversationId,
    Map<String, String>? customData,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationDataModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      conversationId: conversationId ?? this.conversationId,
      customData: customData ?? this.customData,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  String toString() {
    return 'NotificationDataModel(id: $id, type: $type, title: $title, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationDataModel &&
        other.id == id &&
        other.type == type &&
        other.title == title &&
        other.body == body;
  }

  @override
  int get hashCode => Object.hash(id, type, title, body);
}

/// NotificationDataModel ファクトリ用定数
class NotificationTypes {
  static const String dailyReminder = 'daily_reminder';
  static const String milestone = 'milestone';
  static const String premiumUpsell = 'premium_upsell';
  static const String featureUpdate = 'feature_update';
  static const String unknown = 'unknown';
}
