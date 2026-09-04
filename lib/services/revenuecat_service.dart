import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/services.dart' show PlatformException;
import 'package:logging/logging.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

/// Paywall が購入対象として指定できる購読プラン種別。
///
/// 文字列一致(`identifier.contains('monthly')`)ではなく purchases_flutter の
/// [PackageType] で判定する。Offering `default` には未整理の `$rc_lifetime`
/// パッケージが残っており、文字列一致だと想定外のパッケージを拾う危険があるため
/// (STATE.md バックログ「RevenueCat の設定整理」参照)。
enum PremiumPlan {
  monthly,
  annual;

  PackageType get packageType =>
      this == PremiumPlan.annual ? PackageType.annual : PackageType.monthly;
}

/// RevenueCat呼び出し(configure/getCustomerInfo)に設けるタイムアウト。
/// オフライン時にこれらが無期限に待ち続け、起動シーケンス全体が白画面の
/// まま進まなくなる不具合の対策(2026-08-06、DECISIONS.md参照)。
const _kRevenueCatCallTimeout = Duration(seconds: 8);

/// RevenueCat サービス - IAP (In-App Purchase) 統合
///
/// iOS/Android の App Store / Google Play との連携
/// Premium サブスクリプション管理
class RevenueCatService {
  final logger = Logger('RevenueCatService');

  static final RevenueCatService _instance = RevenueCatService._internal();
  
  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _configured = false; // Purchases.configure 済みか
  bool _isPremium = false;

  // RevenueCat 公開SDKキー（--dart-define で注入。プラットフォーム別）
  // 例: --dart-define=REVENUECAT_IOS_KEY=appl_xxx --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
  static const String _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const String _androidApiKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  RevenueCatService._internal();

  factory RevenueCatService() {
    return _instance;
  }

  /// 初期化（アプリ起動時に呼び出し）
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      
      // RevenueCat SDK 初期化
      final apiKey = Platform.isIOS
          ? _iosApiKey
          : Platform.isAndroid
              ? _androidApiKey
              : '';

      if (apiKey.isEmpty) {
        // キー未注入（開発ビルド等）: configure をスキップし、
        // キャッシュ済み Premium 状態のみで動作する。
        logger.warning(
            '[RevenueCat] API key not provided via --dart-define; skipping configure');
        _isPremium = _prefs.getBool('isPremium') ?? false;
        _initialized = true;
        return;
      }

      // リリースビルドはinfoに抑える(購入トラブル調査の手がかりは残しつつ、
      // debugの冗長なネットワーク詳細は出さない)。debug/profileは従来通り。
      await Purchases.setLogLevel(kReleaseMode ? LogLevel.info : LogLevel.debug);
      await Purchases.configure(
        PurchasesConfiguration(apiKey),
      ).timeout(_kRevenueCatCallTimeout);
      _configured = true;

      // 既存の Premium ステータスをロード
      _isPremium = _prefs.getBool('isPremium') ?? false;
      
      _initialized = true;
      logger.info('[RevenueCat] Initialized successfully');
    } catch (e) {
      logger.info('[RevenueCat] Initialization error: $e');
      rethrow;
    }
  }

  /// Premium ステータス取得
  bool get isPremium => _isPremium;

  /// Purchases.configure() が完了しているか。
  ///
  /// false の場合、購入・復元系メソッドは全て早期returnし何もしない
  /// (API key未注入時。例: RevenueCatダッシュボードにAndroidアプリ未登録)。
  /// UI側はこれを見て購読ボタンを無効化するなど、実行前に案内できる。
  bool get isConfigured => _configured;

  /// Supabase user_id と RevenueCat の app_user_id を紐付ける
  ///
  /// Webhook が RevenueCat の app_user_id しか受け取れないため、
  /// これを Supabase の user_id と一致させる必要がある。
  /// restorePurchases() は logIn() 自体は Webhook を発火させないための安全網
  /// （別デバイス購入・レシート再紐付けのトリガーとして機能する）。
  Future<bool> loginWithUserId(String supabaseUserId) async {
    if (!_configured) return false;
    try {
      await Purchases.logIn(supabaseUserId);
      await Purchases.restorePurchases();
      logger.info('[RevenueCat] Logged in as $supabaseUserId');
      return true;
    } catch (e) {
      logger.info('[RevenueCat] loginWithUserId error: $e');
      return false;
    }
  }

  /// Premium ステータスを確認してローカル保存
  Future<bool> checkPremiumStatus() async {
    if (!_configured) return _isPremium;
    try {
      final customerInfo =
          await Purchases.getCustomerInfo().timeout(_kRevenueCatCallTimeout);

      // Premium エンタイトルメント確認
      final entitlements = customerInfo.entitlements;
      _isPremium = entitlements.active.containsKey('Premium') ||
                   entitlements.active.containsKey('voikerchat_premium');

      // ローカル保存
      await _prefs.setBool('isPremium', _isPremium);

      logger.info('[RevenueCat] Premium status checked: $_isPremium');
      return _isPremium;
    } catch (e) {
      logger.info('[RevenueCat] Error checking premium status: $e');
      return _isPremium;
    }
  }

  /// 実行中プラットフォームのストア名(課金エラー文言用)。
  ///
  /// iOS 上に "Play Store" が表示されうる問題(Guideline 2.3.10 の潜在リスク)を
  /// 避けるため、実行中プラットフォームのストア名のみを返す。dart:io の
  /// [Platform] は web で例外を投げるため [kIsWeb] を先に見る。
  String get _storeName {
    if (kIsWeb) return 'the app store';
    if (Platform.isIOS) return 'the App Store';
    if (Platform.isAndroid) return 'the Play Store';
    return 'the app store';
  }

  /// Offering から指定プランのパッケージを [PackageType] で探す。
  ///
  /// `identifier` の文字列一致ではなく PackageType で判定するため、
  /// 未整理の `$rc_lifetime`(PackageType.lifetime)や custom パッケージは
  /// 自動的に無視される。月額・年額として明示的に判定できたものだけを返す。
  Package? _findPackage(Offering offering, PremiumPlan plan) {
    for (final pkg in offering.availablePackages) {
      if (pkg.packageType == plan.packageType) return pkg;
    }
    return null;
  }

  /// Premium 購入フロー
  /// エラー分類: cancelled, network, payment, unknown
  ///
  /// [plan] で月額・年額を指定する(既定は月額。既存呼び出し元との互換のため)。
  Future<Map<String, dynamic>> purchasePremium({
    PremiumPlan plan = PremiumPlan.monthly,
  }) async {
    if (!_configured) {
      return {'success': false, 'error': 'RevenueCat not configured'};
    }
    try {
      final offerings = await Purchases.getOfferings();

      if (offerings.current == null) {
        return {
          'success': false,
          'error': 'offering_not_found',
          'message': 'Offerings not available. Please check your internet connection.',
        };
      }

      final offering = offerings.current!;

      final package = _findPackage(offering, plan);

      if (package == null) {
        return {
          'success': false,
          'error': 'package_not_found',
          'message': 'Subscription package not found.',
        };
      }

      // 購入処理
      try {
        final purchaseResult = await Purchases.purchase(
          PurchaseParams.package(package),
        );

        // 購入成功 → Premium ステータス更新
        final entitlements = purchaseResult.customerInfo.entitlements;
        _isPremium = entitlements.active.containsKey('Premium') ||
                     entitlements.active.containsKey('voikerchat_premium');
        
        if (_isPremium) {
          await _prefs.setBool('isPremium', true);
          logger.info('[RevenueCat] Premium purchased successfully');
          return {
            'success': true,
            'message': 'Welcome to Voikerchat Premium!',
          };
        } else {
          // 購入完了したが、エンタイトルメント未反映
          return {
            'success': false,
            'error': 'entitlement_not_granted',
            'message': 'Purchase completed but subscription not activated. Please try again.',
          };
        }
      } catch (e) {
        // 既に購入済み(ITEM_ALREADY_OWNED / ProductAlreadyPurchasedError)の場合、
        // エラー文言だけで判断せず、実際にentitlementがactiveであることを
        // 確認してから成功として扱う(施策: プレミアム再購入時のシーンロック
        // 解除不具合対応)。entitlementが実際には見つからない異常系は、
        // 下の汎用エラー分類にフォールスルーする。
        if (e is PlatformException &&
            PurchasesErrorHelper.getErrorCode(e) ==
                PurchasesErrorCode.productAlreadyPurchasedError) {
          final alreadyActive = await _confirmActiveEntitlement();
          if (alreadyActive) {
            logger.info(
                '[RevenueCat] Already purchased; entitlement confirmed active');
            return {
              'success': true,
              'message': 'Welcome to Voikerchat Premium!',
            };
          }
        }

        // エラーハンドリング（汎用）
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('cancel')) {
          return {
            'success': false,
            'error': 'cancelled',
            'message': 'Purchase cancelled.',
            'userInitiated': true,
          };
        } else if (errorString.contains('network')) {
          return {
            'success': false,
            'error': 'network',
            'message': 'Network error. Please check your internet connection.',
            'retryable': true,
          };
        } else if (errorString.contains('pending')) {
          return {
            'success': false,
            'error': 'payment_pending',
            'message': 'Payment is pending. Please check your payment method and try again.',
            'retryable': true,
          };
        } else if (errorString.contains('credential') || errorString.contains('invalid')) {
          return {
            'success': false,
            'error': 'invalid_credentials',
            'message':
                'Invalid payment method. Please update your payment info in $_storeName.',
            'retryable': false,
          };
        } else if (errorString.contains('not available') || errorString.contains('region')) {
          return {
            'success': false,
            'error': 'not_available',
            'message': 'Product not available for purchase in your region.',
            'retryable': false,
          };
        } else {
          return {
            'success': false,
            'error': 'unknown_error',
            'message': 'Purchase failed: $e',
            'retryable': true,
          };
        }
      }
    } catch (e) {
      // 予期しないエラー
      return {
        'success': false,
        'error': 'unexpected_error',
        'message': 'Unexpected error: $e',
        'retryable': true,
      };
    }
  }

  /// 「既に購入済み」エラー受信時、実際にentitlementがactiveかを
  /// RevenueCatへ直接問い合わせて確認する(エラー文言だけで判断しない)。
  Future<bool> _confirmActiveEntitlement() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlements = customerInfo.entitlements;
      _isPremium = entitlements.active.containsKey('Premium') ||
          entitlements.active.containsKey('voikerchat_premium');
      if (_isPremium) {
        await _prefs.setBool('isPremium', true);
      }
      return _isPremium;
    } catch (e) {
      logger.info(
          '[RevenueCat] Failed to confirm entitlement after already-purchased error: $e');
      return false;
    }
  }

  /// Premium サブスクリプション情報取得(月額・年額の両方)。
  ///
  /// 戻り値は `{'monthly': {...}, 'annual': {...}}` の形式で、取得できたプラン
  /// のキーのみを含む。両方取得できなかった場合は null。
  /// 各プランの内訳:
  /// - `price`(double): 現地通貨の数値。割引率・月あたり換算の実行時計算に使う
  /// - `priceString`(String): 整形済み価格文字列
  /// - `currencyCode`(String): 通貨コード(通貨ごとの小数桁の判定に使う)
  /// - `title` / `description`(String)
  /// - `introductoryPrice`(Map?): 導入価格が設定されている場合のみ。
  ///   `price` / `priceString` / `period` / `cycles` / `periodUnit` /
  ///   `periodNumberOfUnits` を含む
  Future<Map<String, dynamic>?> getPremiumInfo() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();

      final offering = offerings.current;
      if (offering == null) return null;

      final monthly = _planInfo(_findPackage(offering, PremiumPlan.monthly));
      final annual = _planInfo(_findPackage(offering, PremiumPlan.annual));

      if (monthly == null && annual == null) return null;

      return {
        'monthly': ?monthly,
        'annual': ?annual,
      };
    } catch (e) {
      logger.info('[RevenueCat] Error getting premium info: $e');
      return null;
    }
  }

  Map<String, dynamic>? _planInfo(Package? pkg) {
    if (pkg == null) return null;
    final product = pkg.storeProduct;
    final intro = product.introductoryPrice;
    return {
      'identifier': pkg.identifier,
      'price': product.price,
      'priceString': product.priceString,
      'currencyCode': product.currencyCode,
      'title': product.title,
      'description': product.description,
      if (intro != null)
        'introductoryPrice': {
          'price': intro.price,
          'priceString': intro.priceString,
          'period': intro.period,
          'cycles': intro.cycles,
          'periodUnit': intro.periodUnit.name,
          'periodNumberOfUnits': intro.periodNumberOfUnits,
        },
    };
  }

  /// Premium 復元（別のデバイスから購入した場合）
  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();

      final entitlements = customerInfo.entitlements;
      _isPremium = entitlements.active.containsKey('Premium') ||
                   entitlements.active.containsKey('voikerchat_premium');
      
      await _prefs.setBool('isPremium', _isPremium);
      
      logger.info('[RevenueCat] Purchases restored: $_isPremium');
      return _isPremium;
    } catch (e) {
      logger.info('[RevenueCat] Restore error: $e');
      return false;
    }
  }

  /// Premium キャンセル（ローカル状態のリセット）
  Future<void> resetPremiumStatus() async {
    _isPremium = false;
    await _prefs.setBool('isPremium', false);
    logger.info('[RevenueCat] Premium status reset');
  }
}
