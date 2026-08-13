import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/analytics_service.dart';
import '../services/revenuecat_service.dart';
import '../theme/app_colors.dart';

/// PaywallScreen: プレミアム購入フロー(T-33)。
///
/// ロック中プレミアムシーンのタップ、レート制限到達時、段階的アップセル
/// (PremiumUpsellDialog/Banner)から遷移する共通の購入導線。
/// 購入・復元が成功した場合は `Navigator.pop(context, true)` で呼び出し元に通知する。
class PaywallScreen extends StatefulWidget {
  /// 流入元(usage_logs.metadata.source)。'quota_limit'(上限到達ダイアログ経由)
  /// / 'locked_scene'(ロックシーンタップ経由)。将来呼び出し箇所が増えた際に
  /// unknownが混ざらないよう、既定値は持たせない(呼び出し元で必ず明示する)。
  final String source;

  /// ロックシーン経由の場合の対象シーンID(usage_logs.metadata.scene)。
  final String? sceneId;

  const PaywallScreen({super.key, required this.source, this.sceneId});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _revenueCatService = RevenueCatService();
  final _analyticsService =
      AnalyticsService.getInstance(Supabase.instance.client);
  String? _dynamicPrice;
  bool _isProcessing = false;

  Map<String, dynamic> get _analyticsMetadata => {
        'source': widget.source,
        if (widget.sceneId != null) 'scene': widget.sceneId,
      };

  // RevenueCat未configured(APIキー未注入)時は購読ボタンを無効化する。
  // main.dart起動時に一度だけinitialize()されるため、画面表示時点で確定済み。
  late final bool _purchasingAvailable = _revenueCatService.isConfigured;

  @override
  void initState() {
    super.initState();
    _loadPrice();
    _analyticsService.logEvent(
      event: AnalyticsEvent.upsellShown,
      isPremium: _revenueCatService.isPremium,
      metadata: _analyticsMetadata,
    );
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

  Future<void> _purchase({bool isRetry = false}) async {
    if (_isProcessing) return;
    // purchasePremium()は成功時に内部の_isPremiumをtrueへ書き換えるため、
    // 購入後にgetterを読むと常にtrueになってしまう。is_premiumは「そのイベント
    // 発生時点でPremiumだったか」という観測値であり、upsell_convertedも
    // 他イベントと同じく購入前の状態を記録すべきなので、ここで先にキャプチャ
    // しておく。
    final wasPremiumBeforePurchase = _revenueCatService.isPremium;
    // リトライダイアログ経由の再帰呼び出し(下記_purchase(isRetry: true))でも
    // 毎回記録する(意図どおり。metadata.retryで区別でき、試行回数の可視化に
    // 使える)。
    _analyticsService.logEvent(
      event: AnalyticsEvent.upsellClicked,
      isPremium: wasPremiumBeforePurchase,
      metadata: {
        ..._analyticsMetadata,
        if (isRetry) 'retry': true,
      },
    );
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
        _analyticsService.logEvent(
          event: AnalyticsEvent.upsellConverted,
          isPremium: wasPremiumBeforePurchase,
          metadata: _analyticsMetadata,
        );
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
          await _purchase(isRetry: true);
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

  // 復元(restorePurchases)の成功はupsell_convertedとして記録しない(意図的)。
  // 新規課金ではなく既存購読の復元のため、アップセル効果測定の対象外とする。
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
            ],
          ),
        ),
      ),
      // Guideline 3.1.2対応: スクロール位置に関わらず常に見える固定フッターに
      // 利用規約/プライバシーポリシーへのリンクを配置する(スクロール本文内だと
      // 端末のテキストサイズ設定によっては画面外に出て見えなくなる報告があったため)。
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
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
