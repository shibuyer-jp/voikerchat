import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

import 'ad_config.dart';

/// リワード（報酬型）広告のロードと表示を管理する（モバイル実装）。
///
/// 視聴完了で報酬を得たら [showAd] が true を返すので、
/// 呼び出し側は +5 回ボーナス（[RateLimitService.grantAdBonus]）を付与する。
/// 広告ユニット ID は [AdConfig] に集約済み（テスト/本番の切替は 1 箇所のみ）。
class RewardedAdService {
  final _logger = Logger('RewardedAdService');

  RewardedAd? _ad;
  bool _isLoading = false;

  /// このプラットフォームで広告を表示できるか（モバイルは true）。
  bool get isSupported => true;

  /// 広告がロード済みで即時表示できるか。
  bool get isReady => _ad != null;

  /// 広告を事前ロードする。表示前に呼んでおくと待ち時間が減る。
  /// 既にロード済み/ロード中なら何もしない。
  Future<void> loadAd() async {
    // DIAG(一時): 広告no-fill調査用。呼び出し自体が発生しているか、
    // ガードで早期returnしていないかを可視化する。
    // ignore: avoid_print
    print('[DIAG] loadAd() called: _ad=${_ad != null}, _isLoading=$_isLoading, '
        'unitId=${AdConfig.rewardedUnitId}, useTestAds=${AdConfig.useTestAds}');

    if (_ad != null || _isLoading) {
      // ignore: avoid_print
      print('[DIAG] loadAd() early-return (already loaded or loading)');
      return;
    }
    _isLoading = true;

    // ignore: avoid_print
    print('[DIAG] RewardedAd.load() invoking at ${DateTime.now()}');

    await RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      // 初版は非パーソナライズ広告のみ（npa=1）。ATT/UMP 実装後に解除（AdConfig 参照）。
      request: const AdRequest(nonPersonalizedAds: AdConfig.nonPersonalizedOnly),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          _logger.info('Rewarded ad loaded');
          // ignore: avoid_print
          print('[DIAG] onAdLoaded fired at ${DateTime.now()}');
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _isLoading = false;
          _logger.warning('Rewarded ad failed to load: $error');
          // ignore: avoid_print
          print('[DIAG] onAdFailedToLoad at ${DateTime.now()}: '
              'code=${error.code}, domain=${error.domain}, message=${error.message}, '
              'responseInfo=${error.responseInfo}');
        },
      ),
    );

    // ignore: avoid_print
    print('[DIAG] RewardedAd.load() call returned (this is just the platform '
        'channel call completing, not necessarily the ad result) at ${DateTime.now()}');
  }

  /// 広告を表示する。視聴完了で報酬を得たら true。
  /// 表示後は次回用に自動で再ロードする。未ロードなら false を返す。
  Future<bool> showAd() async {
    final ad = _ad;
    if (ad == null) {
      _logger.info('showAd called but no ad is ready');
      return false;
    }
    _ad = null; // 同一インスタンスの二重表示を防ぐ

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadAd(); // 次回用に再ロード
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logger.warning('Rewarded ad failed to show: $error');
        ad.dispose();
        loadAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        // 報酬獲得（視聴完了）。確定はダイアログ閉鎖後に行う。
        earned = true;
      },
    );

    return completer.future;
  }

  /// 保持中の広告を破棄する。
  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
