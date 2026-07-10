import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logging/logging.dart';

/// 端末内蔵の読み上げ(TTS)をラップするサービス。iOS/Android/Web 対応。
///
/// アシスタントの日本語応答を ja-JP で読み上げる。
/// 速度はプラットフォームでスケールが異なる点に注意:
/// - iOS(AVSpeechUtterance): 0.5 が標準速度。0.9 はほぼ最速で早口になる
/// - Android/Web: 1.0 が標準速度。学習用にやや遅めの 0.9 を既定とする
class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  final Logger _logger = Logger('TextToSpeechService');

  /// プラットフォーム別の既定読み上げ速度。
  static double get defaultRate =>
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ? 0.5 : 0.9;

  bool _isSupported = false;
  bool _isSpeaking = false;
  void Function()? _onCompleteCallback;

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
      await _flutterTts.setSpeechRate(defaultRate);
      await _flutterTts.setPitch(1.0);

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
      await _flutterTts.setSpeechRate(rate ?? defaultRate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      _logger.severe('Error during TTS speak: $e');
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
