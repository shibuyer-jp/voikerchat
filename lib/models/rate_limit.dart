class RateLimit {
  final String userId;
  final int dailyLimit;
  final int usedToday;
  final DateTime lastResetUtc;
  final bool isPremium;

  RateLimit({
    required this.userId,
    required this.dailyLimit,
    required this.usedToday,
    required this.lastResetUtc,
    required this.isPremium,
  });

  /// Returns remaining calls for today
  int get remainingCalls => isPremium ? 999 : (dailyLimit - usedToday).clamp(0, dailyLimit);

  /// Returns true if user can make another call
  bool get canMakeCall => isPremium || usedToday < dailyLimit;

  /// Returns percentage of daily limit used (0-100)
  double get usagePercentage => isPremium ? 0 : (usedToday / dailyLimit * 100).clamp(0, 100);

  factory RateLimit.fromJson(Map<String, dynamic> json) {
    return RateLimit(
      userId: json['user_id'] as String,
      dailyLimit: json['daily_limit'] as int? ?? 5,
      usedToday: json['used_today'] as int? ?? 0,
      lastResetUtc: DateTime.parse(json['last_reset_utc'] as String? ?? DateTime.now().toIso8601String()),
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'daily_limit': dailyLimit,
        'used_today': usedToday,
        'last_reset_utc': lastResetUtc.toIso8601String(),
        'is_premium': isPremium,
      };
}
