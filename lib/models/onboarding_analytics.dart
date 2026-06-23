import 'package:json_annotation/json_annotation.dart';

part 'onboarding_analytics.g.dart';

/// OnboardingAnalytics: オンボーディング過程の分析データ
@JsonSerializable()
class OnboardingAnalytics {
  /// ID（UUID）
  final String id;

  /// ユーザーID（auth.users -> id）
  final String userId;

  /// 完了したステップ（1-5、0 = 未開始）
  final int stepCompleted;

  /// ステップ完了時間（秒単位）
  final int timeSpentSeconds;

  /// スキップ回数
  final int skipCount;

  /// ヒント使用回数（診断テスト）
  final int hintUsage;

  /// オンボーディング完了時刻
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? completedAt;

  /// 記録作成日時
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;

  OnboardingAnalytics({
    required this.id,
    required this.userId,
    required this.stepCompleted,
    required this.timeSpentSeconds,
    required this.skipCount,
    required this.hintUsage,
    required this.createdAt,
    this.completedAt,
  });

  factory OnboardingAnalytics.fromJson(Map<String, dynamic> json) =>
      _$OnboardingAnalyticsFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingAnalyticsToJson(this);

  /// Supabase に送信するための Map
  Map<String, dynamic> toSupabase() => {
        'id': id,
        'user_id': userId,
        'step_completed': stepCompleted,
        'time_spent_seconds': timeSpentSeconds,
        'skip_count': skipCount,
        'hint_usage': hintUsage,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

DateTime? _dateTimeFromJson(dynamic json) {
  if (json == null) return null;
  if (json is String) return DateTime.tryParse(json);
  return null;
}

String? _dateTimeToJson(DateTime? dateTime) => dateTime?.toIso8601String();
