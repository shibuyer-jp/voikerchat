// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_history_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationHistory _$NotificationHistoryFromJson(Map<String, dynamic> json) =>
    NotificationHistory(
      id: (json['id'] as num).toInt(),
      userId: json['userId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      payload: json['payload'] as String?,
      isRead: json['isRead'] as bool? ?? false,
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
  'userId': instance.userId,
  'title': instance.title,
  'body': instance.body,
  'payload': instance.payload,
  'isRead': instance.isRead,
  'received_at': instance.receivedAt.toIso8601String(),
  'read_at': instance.readAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
