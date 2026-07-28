import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/revenuecat_service.dart';
import '../theme/app_colors.dart';

/// PaywallScreen: プレミアム購入フロー(T-33)。
///
/// ロック中プレミアムシーンのタップ、レート制限到達時、段階的アップセル
/// (PremiumUpsellDialog/Banner)から遷移する共通の購入導線。
/// 購入・復元が成功した場合は `Navigator.pop(context, true)` で呼び出し元に通知する。
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _revenueCatService = RevenueCatService();
  String? _dynamicPrice;
  bool _isProcessing = false;

  // RevenueCat未configured(APIキー未注入)時は購読ボタンを無効化する。
  // main.dart起動時に一度だけinitialize()されるため、画面表示時点で確定済み。
  late final bool _purchasingAvailable = _revenueCatService.isConfigured;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  /// RevenueCat の Offering から現地価格を取得する。
  /// 取得できない場合は ARB の `premiumPriceFallback`(固定フォールバック価格)を使う。
  /// いずれの値も価格のみ(期間表記なし)で、表示時に `premiumPriceWithPeriod` で期間を付与する。
  Future<void> _loadPrice() async {
    final info = await _revenueCatService.getPremiumInfo();
    if (!mounted) return;
    final price = info?['price'];
    if (price is String && price.isNotEmpty) {
      setState(() => _dynamicPrice = price);
    }
  }

  Future<void> _openLink(String path) async {
    final uri = Uri.parse('https://voikerchat.com/$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _purchase() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final l = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l.processingPurchase),
          ],
        ),
      ),
    );

    try {
      final result = await _revenueCatService.purchasePremium();
      if (!mounted) return;
      Navigator.pop(context); // 処理中ダイアログを閉じる

      if (result['success'] == true) {
        Navigator.pop(context, true); // ペイウォール自体を成功として閉じる
        return;
      }

      final userInitiated = result['userInitiated'] as bool? ?? false;
      if (userInitiated) return; // ユーザーキャンセルは無表示

      final message = result['message'] as String? ?? l.purchaseFailed;
      final retryable = result['retryable'] as bool? ?? false;

      if (retryable) {
        if (!mounted) return;
        final retry = await _showRetryDialog(message);
        if (retry == true && mounted) {
          setState(() => _isProcessing = false);
          await _purchase();
          return;
        }
      } else {
        if (mounted) await _showErrorDialog(message);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showRetryDialog(String message) {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.purchaseFailedTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.retry),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String message) {
    final l = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.errorTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final l = AppLocalizations.of(context);

    try {
      final restored = await _revenueCatService.restorePurchases();
      if (!mounted) return;

      if (restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.restoreSuccess)),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.restoreNotFound)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final priceValue = _dynamicPrice ?? l.premiumPriceFallback;
    final price = l.premiumPriceWithPeriod(priceValue);

    return Scaffold(
      appBar: AppBar(title: Text(l.paywallTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.premiumSheetSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _PaywallFeature(
                icon: Icons.forum,
                title: l.featureUnlimitedTitle,
                description: l.featureUnlimitedDesc,
              ),
              const SizedBox(height: 16),
              _PaywallFeature(
                icon: Icons.movie_filter,
                title: l.featureAnimeTitle,
                description: l.featureAnimeDesc,
              ),
              const SizedBox(height: 16),
              _PaywallFeature(
                icon: Icons.block,
                title: l.featureNoAdsTitle,
                description: l.featureNoAdsDesc,
              ),
              const SizedBox(height: 16),
              _PaywallFeature(
                icon: Icons.record_voice_over,
                title: l.featureVoiceTitle,
                description: l.featureVoiceDesc,
              ),
              const SizedBox(height: 16),
              _PaywallFeature(
                icon: Icons.bar_chart,
                title: l.featureStatsTitle,
                description: l.featureStatsDesc,
              ),
              const SizedBox(height: 32),
              Text(
                price,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_isProcessing || !_purchasingAvailable) ? null : _purchase,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.subscribeCta),
              ),
              if (!_purchasingAvailable) ...[
                const SizedBox(height: 8),
                Text(
                  l.subscribeUnavailableMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isProcessing ? null : _restore,
                child: Text(l.restorePurchasesButton),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _openLink('Terms-of-Service-v1.0'),
                    child: Text(
                      l.termsOfService,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Text('・'),
                  TextButton(
                    onPressed: () => _openLink('Privacy-Policy-v1.0'),
                    child: Text(
                      l.privacyPolicy,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PaywallFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.brand),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
