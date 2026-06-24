// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingAnalytics _$OnboardingAnalyticsFromJson(Map<String, dynamic> json) =>
    OnboardingAnalytics(
      id: json['id'] as String,
      userId: json['userId'] as String,
      stepCompleted: (json['stepCompleted'] as num).toInt(),
      timeSpentSeconds: (json['timeSpentSeconds'] as num).toInt(),
      skipCount: (json['skipCount'] as num).toInt(),
      hintUsage: (json['hintUsage'] as num).toInt(),
      createdAt: _dateTimeFromJson(json['createdAt']),
      completedAt: _dateTimeFromJson(json['completedAt']),
    );

Map<String, dynamic> _$OnboardingAnalyticsToJson(
  OnboardingAnalytics instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'stepCompleted': instance.stepCompleted,
  'timeSpentSeconds': instance.timeSpentSeconds,
  'skipCount': instance.skipCount,
  'hintUsage': instance.hintUsage,
  'completedAt': _dateTimeToJson(instance.completedAt),
  'createdAt': _dateTimeToJson(instance.createdAt),
};
