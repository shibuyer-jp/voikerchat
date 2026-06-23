import 'package:flutter/material.dart';
import '../models/rate_limit.dart';

/// Widget to display rate limit status above message input
/// Shows remaining calls and usage progress for free tier users
class RateLimitWidget extends StatelessWidget {
  final RateLimit? rateLimit;
  final VoidCallback? onUpgradePressed;

  const RateLimitWidget({
    Key? key,
    this.rateLimit,
    this.onUpgradePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              color: Colors.amber[600],
            ),
            const SizedBox(width: 6),
            Text(
              'Premium - Unlimited',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber[600],
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
                '$remaining / ${rateLimit!.dailyLimit} calls remaining today',
                style: TextStyle(
                  fontSize: 12,
                  color: isNearLimit ? Colors.red[700] : Colors.grey[600],
                  fontWeight: isNearLimit ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (onUpgradePressed != null)
                InkWell(
                  onTap: onUpgradePressed,
                  child: Text(
                    'Go Premium',
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
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? Colors.red[600]! : Colors.blue[500]!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
