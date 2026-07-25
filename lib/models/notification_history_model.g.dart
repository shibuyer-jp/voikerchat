// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_history_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationHistory _$NotificationHistoryFromJson(Map<String, dynamic> json) =>
    NotificationHistory(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      payload: json['payload'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      status: json['status'] == null
          ? NotificationHistoryStatus.delivered
          : NotificationHistory._statusFromJson(json['status'] as String),
      receivedAt: DateTime.parse(json['received_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$NotificationHistoryToJson(
  NotificationHistory instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'title': instance.title,
  'body': instance.body,
  'payload': instance.payload,
  'is_read': instance.isRead,
  'status': NotificationHistory._statusToJson(instance.status),
  'received_at': instance.receivedAt.toIso8601String(),
  'read_at': instance.readAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
