import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/premium_upsell_service.dart';

/// PremiumUpsellToast: Stage 1用トースト通知
class PremiumUpsellToast extends StatelessWidget {
  final VoidCallback? onDetailsTap;
  final VoidCallback? onDismiss;

  const PremiumUpsellToast({
    super.key,
    this.onDetailsTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  PremiumUpsellService.getStageMessage(
                    PremiumUpsellStage.stage1,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDetailsTap,
            child: Text(l.details),
          ),
        ],
      ),
    );
  }
}

/// PremiumUpsellDialog: Stage 2用ダイアログ
class PremiumUpsellDialog extends StatelessWidget {
  final VoidCallback? onSubscribeTap;
  final VoidCallback? onDismiss;

  const PremiumUpsellDialog({
    super.key,
    this.onSubscribeTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.premiumDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.premiumDialogBody),
          const SizedBox(height: 16),
          Text(
            l.premiumBenefitUnlimited,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            l.premiumBenefitAllScenes,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            l.premiumBenefitStats,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(l.later),
        ),
        ElevatedButton(
          onPressed: onSubscribeTap,
          child: Text(l.subscribeMonthlyPrice),
        ),
      ],
    );
  }
}

/// PremiumUpsellBanner: Stage 3用バナー
class PremiumUpsellBanner extends StatelessWidget {
  final VoidCallback? onSubscribeTap;
  final VoidCallback? onDismiss;

  const PremiumUpsellBanner({
    super.key,
    this.onSubscribeTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.streak7Achieved,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.premiumBannerBody,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubscribeTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              child: Text(
                l.subscribeNow,
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
