import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
///
/// 1.1.0 で月額・年額の2プラン対応にした。機能リストの下に選択式のプランカードを
/// 2枚並べ、CTA ボタン1つで「選択中のプラン」を購入する。割引率・月あたり換算は
/// ストアフロントごとに月額・年額の価格比が異なるため実行時計算とし、
/// ハードコードしない(DECISIONS.md 2026-09-04)。
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

  /// RevenueCat の getPremiumInfo() の戻り値(`{'monthly': {...}, 'annual': {...}}`)。
  /// 取得できたプランのキーのみを含む。両方取れなければ null。
  Map<String, dynamic>? _premiumInfo;

  /// 初期選択プラン。'annual' 固定だが、将来変更しても計測(default_plan /
  /// plan_changed)が追随できるよう単一の定義元にしておく。
  static const PremiumPlan _initialPlan = PremiumPlan.annual;

  PremiumPlan _selectedPlan = _initialPlan;
  bool _isProcessing = false;

  Map<String, dynamic>? get _monthlyInfo =>
      _premiumInfo?['monthly'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _annualInfo =>
      _premiumInfo?['annual'] as Map<String, dynamic>?;

  /// 月額・年額の両方が取得でき、ユーザーが選べる状態か。
  bool get _hasPlanChoice => _monthlyInfo != null && _annualInfo != null;

  /// 少なくとも1プランの価格が取得できているか(false なら単一プランの
  /// フォールバック表示に切り替える)。
  bool get _hasAnyPlan => _monthlyInfo != null || _annualInfo != null;

  /// 実際に購入対象となるプラン。選択式なら選択中、片方しか無ければその片方、
  /// どちらも無ければ月額(既存の単一プラン挙動)。
  PremiumPlan get _effectivePlan {
    if (_hasPlanChoice) return _selectedPlan;
    if (_annualInfo != null) return PremiumPlan.annual;
    return PremiumPlan.monthly;
  }

  /// 初期選択から能動的に変更したか(選択式のときのみ true になりうる)。
  bool get _planChanged => _hasPlanChoice && _selectedPlan != _initialPlan;

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
    _loadPlans();
    _analyticsService.logEvent(
      event: AnalyticsEvent.upsellShown,
      isPremium: _revenueCatService.isPremium,
      metadata: {
        ..._analyticsMetadata,
        'default_plan': _initialPlan.name,
      },
    );
  }

  /// RevenueCat の Offering から月額・年額の現地価格を取得する。
  /// 取得できなかったプランのカードは表示せず、両方取得できなければ
  /// ARB の `premiumPriceFallback` による単一プラン表示にフォールバックする。
  Future<void> _loadPlans() async {
    final info = await _revenueCatService.getPremiumInfo();
    if (!mounted) return;
    setState(() {
      _premiumInfo = info;
      // 選択中プランの価格が取れていない場合は、取得できた方へ寄せる。
      if (!_hasPlanChoice) {
        if (_annualInfo != null) {
          _selectedPlan = PremiumPlan.annual;
        } else if (_monthlyInfo != null) {
          _selectedPlan = PremiumPlan.monthly;
        }
      }
    });
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
    final plan = _effectivePlan;
    final planChanged = _planChanged;
    // リトライダイアログ経由の再帰呼び出し(下記_purchase(isRetry: true))でも
    // 毎回記録する(意図どおり。metadata.retryで区別でき、試行回数の可視化に
    // 使える)。
    _analyticsService.logEvent(
      event: AnalyticsEvent.upsellClicked,
      isPremium: wasPremiumBeforePurchase,
      metadata: {
        ..._analyticsMetadata,
        'plan': plan.name,
        'plan_changed': planChanged,
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
      final result = await _revenueCatService.purchasePremium(plan: plan);
      if (!mounted) return;
      Navigator.pop(context); // 処理中ダイアログを閉じる

      if (result['success'] == true) {
        _analyticsService.logEvent(
          event: AnalyticsEvent.upsellConverted,
          isPremium: wasPremiumBeforePurchase,
          metadata: {
            ..._analyticsMetadata,
            'plan': plan.name,
            'plan_changed': planChanged,
          },
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

  /// 通貨コードに応じた小数桁で金額を整形する(円は0桁、ドル・ペソは2桁)。
  /// 表示のためだけに使い、割引率などの計算には storeProduct.price(数値)を使う。
  String _formatCurrency(num amount, String currencyCode) {
    final format = NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toLanguageTag(),
      name: currencyCode,
    );
    return format.format(amount);
  }

  /// 割引率(%)。年額を1年間 月額で払った場合との比較。
  /// 月額・年額のどちらかが欠けていれば null(誤った割引率を出さない、1-e)。
  int? _discountPercent() {
    final monthly = _monthlyInfo;
    final annual = _annualInfo;
    if (monthly == null || annual == null) return null;
    final monthlyPrice = (monthly['price'] as num?)?.toDouble() ?? 0;
    final annualPrice = (annual['price'] as num?)?.toDouble() ?? 0;
    if (monthlyPrice <= 0 || annualPrice <= 0) return null;
    final pct = (1 - annualPrice / (monthlyPrice * 12)) * 100;
    if (pct <= 0) return null;
    return pct.round();
  }

  /// 年額の月あたり換算(年額price / 12)。
  /// 月額・年額のどちらかが欠けていれば null(1-e)。
  String? _perMonthEquivalent() {
    final monthly = _monthlyInfo;
    final annual = _annualInfo;
    if (monthly == null || annual == null) return null;
    final annualPrice = (annual['price'] as num?)?.toDouble() ?? 0;
    if (annualPrice <= 0) return null;
    return _formatCurrency(annualPrice / 12, annual['currencyCode'] as String);
  }

  String _durationLabel(AppLocalizations l, String unit, int count) {
    switch (unit) {
      case 'day':
        return l.paywallDurationDays(count);
      case 'week':
        return l.paywallDurationWeeks(count);
      case 'year':
        return l.paywallDurationYears(count);
      case 'month':
      default:
        return l.paywallDurationMonths(count);
    }
  }

  /// 導入価格(Introductory Offer)の表示文言。ストア側に導入価格が設定されて
  /// いる場合のみ非 null(1.1.0 では常に null。表示ロジックのみ先行実装)。
  /// 導入価格・導入期間・その後の通常価格・自動更新の4点を同一文で示す。
  String? _introOfferText(
    AppLocalizations l,
    Map<String, dynamic> planInfo,
    String regularPriceLine,
  ) {
    final intro = planInfo['introductoryPrice'] as Map<String, dynamic>?;
    if (intro == null) return null;
    final introPrice = intro['priceString'] as String? ?? '';
    final unit = intro['periodUnit'] as String? ?? 'month';
    final unitsPerCycle = (intro['periodNumberOfUnits'] as num?)?.toInt() ?? 1;
    final cycles = (intro['cycles'] as num?)?.toInt() ?? 1;
    final duration = _durationLabel(l, unit, unitsPerCycle * cycles);
    return l.paywallIntroOffer(introPrice, duration, regularPriceLine);
  }

  String _priceLine(
    AppLocalizations l,
    PremiumPlan plan,
    Map<String, dynamic> planInfo,
  ) {
    final priceStr = planInfo['priceString'] as String? ?? '';
    return plan == PremiumPlan.annual
        ? l.paywallPricePerYear(priceStr)
        : l.premiumPriceWithPeriod(priceStr);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

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
              ...(_hasAnyPlan ? _buildPlanCards(l) : _buildFallbackPrice(l)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    (_isProcessing || !_purchasingAvailable) ? null : _purchase,
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

  /// 単一プランのフォールバック表示(月額・年額とも価格取得に失敗した場合)。
  List<Widget> _buildFallbackPrice(AppLocalizations l) {
    final price = l.premiumPriceWithPeriod(l.premiumPriceFallback);
    return [
      Text(
        price,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.brand,
            ),
      ),
    ];
  }

  List<Widget> _buildPlanCards(AppLocalizations l) {
    final cards = <Widget>[];
    final monthly = _monthlyInfo;
    if (monthly != null) {
      cards.add(_buildPlanCard(
        l,
        plan: PremiumPlan.monthly,
        info: monthly,
        heading: l.paywallPlanMonthlyLabel,
      ));
    }
    final annual = _annualInfo;
    if (annual != null) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(_buildPlanCard(
        l,
        plan: PremiumPlan.annual,
        info: annual,
        heading: l.paywallPlanAnnualLabel,
      ));
    }
    return cards;
  }

  Widget _buildPlanCard(
    AppLocalizations l, {
    required PremiumPlan plan,
    required Map<String, dynamic> info,
    required String heading,
  }) {
    final selected = _effectivePlan == plan;
    final discount = plan == PremiumPlan.annual ? _discountPercent() : null;
    final perMonth = plan == PremiumPlan.annual ? _perMonthEquivalent() : null;
    final priceLine = _priceLine(l, plan, info);
    final introText = _introOfferText(l, info, priceLine);

    return InkWell(
      onTap: _hasPlanChoice
          ? () => setState(() => _selectedPlan = plan)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.brand : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.brand : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        heading,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (discount != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l.paywallDiscountBadge(discount),
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 主表示: 実際に課金される金額 + 期間(Guideline 3.1.2)。
                  Text(
                    priceLine,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                        ),
                  ),
                  // 従表示: 月あたり換算(小さめ・グレー。主表示にはしない)。
                  if (perMonth != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      l.paywallPerMonthEquivalent(perMonth),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (introText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      introText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
