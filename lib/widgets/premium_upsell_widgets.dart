import 'package:flutter/material.dart';
import '../services/premium_upsell_service.dart';

/// PremiumUpsellToast: Stage 1用トースト通知
class PremiumUpsellToast extends StatelessWidget {
  final VoidCallback? onDetailsTap;
  final VoidCallback? onDismiss;

  const PremiumUpsellToast({
    Key? key,
    this.onDetailsTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            child: const Text('詳細'),
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
    Key? key,
    this.onSubscribeTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Premium メンバーになりませんか？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium なら無制限に学習できます。',
          ),
          const SizedBox(height: 16),
          const Text(
            '✓ 1日無制限に使用可能',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            '✓ すべてのアニメシーン解放',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            '✓ 詳細な統計ダッシュボード',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('後で'),
        ),
        ElevatedButton(
          onPressed: onSubscribeTap,
          child: const Text('登録（\$4.99/月）'),
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
    Key? key,
    this.onSubscribeTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              const Expanded(
                child: Text(
                  '🎉 7日連続達成！',
                  style: TextStyle(
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
          const Text(
            'Premium でアニメシーンも解放して、学習を加速させましょう！',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubscribeTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              child: const Text(
                'いますぐ登録',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
