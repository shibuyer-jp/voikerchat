import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../models/rate_limit.dart';

/// Widget to display rate limit status above message input
/// Shows remaining calls and usage progress for free tier users
class RateLimitWidget extends StatelessWidget {
  final RateLimit? rateLimit;
  final VoidCallback? onUpgradePressed;

  /// 「広告を見て +5回」ボタンを表示するか（無料・上限間近・本日上限<10 のとき）。
  final bool showWatchAdButton;

  /// 広告のロード/表示中はボタンを無効化＆スピナー表示する。
  final bool isAdLoading;

  /// 広告ボタンが押されたときのコールバック。
  final VoidCallback? onWatchAd;

  const RateLimitWidget({
    super.key,
    this.rateLimit,
    this.onUpgradePressed,
    this.showWatchAdButton = false,
    this.isAdLoading = false,
    this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (rateLimit == null) {
      return const SizedBox.shrink();
    }

    // Premium users: no limit indicator
    if (rateLimit!.isPremium) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(
          children: [
            Icon(
              Icons.flash_on,
              size: 16,
              color: Colors.amber.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              l.premiumUnlimited,
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Free tier: show usage
    final remaining = rateLimit!.remainingCalls;
    final usagePercent = rateLimit!.usagePercentage;
    final isNearLimit = remaining <= 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: remaining calls + upgrade button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.callsRemainingToday(remaining, rateLimit!.dailyLimit),
                style: TextStyle(
                  fontSize: 12,
                  color: isNearLimit ? Colors.red[700] : Colors.grey.shade600,
                  fontWeight: isNearLimit ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (onUpgradePressed != null)
                InkWell(
                  onTap: onUpgradePressed,
                  child: Text(
                    l.goPremium,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: usagePercent / 100,
              minHeight: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? Colors.red[600]! : Colors.blue[500]!,
              ),
            ),
          ),
          // 「広告を見て +5回」ボタン（上限間近のときのみ）
          if (showWatchAdButton && onWatchAd != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isAdLoading ? null : onWatchAd,
                icon: isAdLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline, size: 18),
                label: Text(
                  l.watchAdForBonus,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
