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
    if (_ad != null || _isLoading) return;
    _isLoading = true;

    await RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          _logger.info('Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _isLoading = false;
          _logger.warning('Rewarded ad failed to load: $error');
        },
      ),
    );
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
