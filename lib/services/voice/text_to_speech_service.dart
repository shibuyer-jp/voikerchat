import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logging/logging.dart';

/// 端末内蔵の読み上げ(TTS)をラップするサービス。iOS/Android/Web 対応。
///
/// アシスタントの日本語応答を ja-JP で読み上げる。
/// 速度はプラットフォームでスケールが異なる点に注意:
/// - iOS(AVSpeechUtterance): 0.5 が標準速度。0.9 はほぼ最速で早口になる
/// - Android: flutter_tts が値を2倍してネイティブに渡す(rate * 2.0f)ため
///   0.5 が標準速度。0.9 を渡すとネイティブ1.8倍速の早口になる
/// - Web: 1.0 が標準速度。学習用にやや遅めの 0.9 を既定とする
class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  final Logger _logger = Logger('TextToSpeechService');

  /// プラットフォーム別の既定読み上げ速度。
  /// iOS/Android とも 0.5 = 標準。学習用にやや遅めの 0.45(≒0.9倍速)。
  static double get defaultRate {
    if (kIsWeb) return 0.9;
    return 0.45;
  }

  bool _isSupported = false;
  bool _isSpeaking = false;
  void Function()? _onCompleteCallback;

  /// 自動選択した高品質日本語音声（未選択なら null = OS既定音声）。
  /// 注意: iOS ネイティブ実装は setLanguage で選択音声を破棄する
  /// (self.voice = nil) ため、speak() 側で毎回再適用する。
  Map<String, String>? _selectedJaVoice;

  bool get isSupported => _isSupported;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    try {
      // iOS: 録音(STT)と再生(TTS)を滑らかに行き来するためのオーディオセッション設定。
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }

      await _flutterTts.setLanguage('ja-JP');
      await _selectBestJapaneseVoice();
      await _flutterTts.setSpeechRate(defaultRate);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0); // 明示的に最大音量(0.0〜1.0)

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _logger.info('TTS start.');
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _logger.info('TTS complete.');
        _onCompleteCallback?.call();
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        _logger.info('TTS cancel.');
      });
      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
        _logger.severe('TTS error: $message');
      });

      _isSupported = true;
      _logger.info('TextToSpeechService initialized.');
    } catch (e) {
      _isSupported = false;
      _logger.severe('Failed to initialize TTS: $e');
    }
  }

  Future<void> speak(
    String text, {
    String localeId = 'ja-JP',
    double? rate, // 未指定時はプラットフォーム別の defaultRate を使用
    double pitch = 1.0,
  }) async {
    if (!_isSupported) {
      _logger.warning('TTS not supported/initialized.');
      return;
    }

    try {
      final dynamic available = await _flutterTts.isLanguageAvailable(localeId);
      if (available is bool && !available) {
        _logger.severe('TTS language not available: $localeId');
        return;
      }

      await _flutterTts.setLanguage(localeId);
      // iOS は setLanguage で選択音声が破棄されるため、日本語読み上げ時は
      // 高品質音声を毎回再適用する（未選択・非日本語時は OS 既定のまま）。
      if (_selectedJaVoice != null && localeId.toLowerCase().startsWith('ja')) {
        await _flutterTts.setVoice(_selectedJaVoice!);
      }
      await _flutterTts.setSpeechRate(rate ?? defaultRate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      _logger.severe('Error during TTS speak: $e');
    }
  }

  /// 端末にインストール済みの日本語音声から最高品質のものを自動選択する。
  ///
  /// - iOS: quality = premium > enhanced > default（識別子で厳密指定）
  /// - Android: quality = very high > high > normal（name+locale で指定、
  ///   ネットワーク必須音声は遅延・オフライン不可のため除外）
  /// - Web: 品質情報が取得できないため選択しない（既定音声のまま）
  ///
  /// 高品質音声が見つからない場合・取得や設定に失敗した場合は
  /// 何もせず OS 既定音声にフォールバックする（従来と同じ挙動）。
  Future<void> _selectBestJapaneseVoice() async {
    if (kIsWeb) return;
    try {
      final dynamic voices = await _flutterTts.getVoices;
      if (voices is! List) return;

      Map<String, String>? best;
      var bestScore = 1; // 1 = 既定品質。これを上回る音声のみ採用する。
      for (final dynamic v in voices) {
        if (v is! Map) continue;
        final voice = <String, String>{
          for (final entry in v.entries)
            entry.key.toString(): entry.value?.toString() ?? '',
        };
        final locale = (voice['locale'] ?? '').toLowerCase();
        if (!locale.startsWith('ja')) continue;
        if (voice['network_required'] == '1') continue; // Android のみ存在
        final score = _voiceQualityScore(voice['quality']);
        if (score > bestScore) {
          bestScore = score;
          best = voice;
        }
      }

      if (best == null) {
        _logger.info('No enhanced ja voice found; using default voice.');
        return;
      }

      final selection = <String, String>{
        'name': best['name'] ?? '',
        'locale': best['locale'] ?? '',
        // iOS はこの識別子で音声を厳密に特定する（Android では無視される）。
        if ((best['identifier'] ?? '').isNotEmpty)
          'identifier': best['identifier']!,
      };
      final dynamic ok = await _flutterTts.setVoice(selection);
      if (ok == 1) {
        _selectedJaVoice = selection;
        _logger.info(
          'TTS voice upgraded: ${best['name']} (quality: ${best['quality']})',
        );
      }
    } catch (e) {
      // 失敗しても致命的ではない: 既定音声で読み上げを継続する。
      _logger.warning('Voice quality selection skipped: $e');
    }
  }

  /// flutter_tts が返す品質文字列を共通スコアに変換する。
  /// iOS: default / enhanced / premium、Android: normal / high / very high 等。
  int _voiceQualityScore(String? quality) {
    switch (quality) {
      case 'premium': // iOS 最高品質
      case 'very high': // Android 最高品質
        return 3;
      case 'enhanced': // iOS 拡張品質
      case 'high': // Android 高品質
        return 2;
      default:
        return 1;
    }
  }

  Future<void> stop() async {
    _logger.info('Stopping TTS.');
    await _flutterTts.stop();
  }

  void setCompletionHandler(void Function() onComplete) {
    _onCompleteCallback = onComplete;
  }

  void dispose() {
    _logger.info('Disposing TextToSpeechService.');
    _flutterTts.stop();
  }
}
