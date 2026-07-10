import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 端末内蔵の音声認識(STT)をラップするサービス。
///
/// iOS/Android/Web を単一実装で賄う（speech_to_text がPF差を吸収）。
/// iOSは1認識タスク約1分で強制終了し連続再起動でスロットリングされるため、
/// 1ターン=1認識のPush-to-Talk運用を前提とする（自動再起動ループは持たない）。
class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  final Logger _logger = Logger('SpeechRecognitionService');

  bool _isSupported = false;
  bool _hasCompletedCurrentSession = false;

  void Function()? _onCompleteCallback;
  void Function(String errorCode)? _onErrorCallback;

  /// この端末/ブラウザで音声認識が使えるか（未対応・権限拒否なら false）。
  bool get isSupported => _isSupported;

  /// 現在リッスン中か。
  bool get isListening => _speech.isListening;

  /// 一度きりの初期化＋マイク/音声認識の許可要求。使用可能なら true。
  Future<bool> initialize() async {
    try {
      _isSupported = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      _logger.info('SpeechToText initialized. supported=$_isSupported');
      return _isSupported;
    } catch (e) {
      _logger.severe('Failed to initialize SpeechToText: $e');
      _isSupported = false;
      return false;
    }
  }

  /// リッスン開始。onResult は途中/確定を逐次通知し、onComplete は自然/強制終了で1回だけ発火する。
  Future<void> start({
    String localeId = 'ja-JP',
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onComplete,
    void Function(String errorCode)? onError,
  }) async {
    if (!_isSupported) {
      _logger.warning('SpeechToText not supported/initialized.');
      onError?.call('not_initialized');
      return;
    }

    _onCompleteCallback = onComplete;
    _onErrorCallback = onError;
    _hasCompletedCurrentSession = false;

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(_dedupe(result.recognizedWords), result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: localeId,
        ),
      );
      _logger.info('SpeechToText listening (locale=$localeId).');
    } catch (e) {
      _logger.severe('Failed to start listen: $e');
      onError?.call('start_failed');
    }
  }

  /// iOS 17+ の認識リセットバグ緩和策(プラグイン側の結果連結)の副作用で、
  /// 発話中にポーズを挟むと同一フレーズが二重連結されることがある
  /// (例:「おはようございます」→「おはようございますおはようございます」)。
  /// 前半と後半が完全一致する場合のみ前半を採用する。
  /// 「はいはい」等の正当な繰り返し表現を誤って潰さないよう、
  /// 片側5文字以上の場合に限定する。
  String _dedupe(String transcript) {
    final s = transcript.trim();
    if (s.length >= 10 && s.length.isEven) {
      final half = s.length ~/ 2;
      if (s.substring(0, half) == s.substring(half)) {
        _logger.info('Deduped doubled transcript (len=${s.length}).');
        return s.substring(0, half);
      }
    }
    return s;
  }

  /// 停止して確定（onComplete が発火する）。
  Future<void> stop() async {
    _logger.info('Stopping SpeechToText.');
    await _speech.stop();
  }

  /// 中断（確定させず破棄）。
  Future<void> cancel() async {
    _logger.info('Canceling SpeechToText.');
    await _speech.cancel();
  }

  void dispose() {
    _logger.info('Disposing SpeechRecognitionService.');
    _speech.cancel();
  }

  void _handleStatus(String status) {
    _logger.info('SpeechToText status=$status');
    // iOSは約1分で強制終了、Androidは無音約5秒で自動停止。どちらも正常終了として扱う。
    if (status == 'done' || status == 'notListening') {
      if (!_hasCompletedCurrentSession) {
        _hasCompletedCurrentSession = true;
        _onCompleteCallback?.call();
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    _logger.severe(
      'SpeechToText error: ${error.errorMsg} (permanent=${error.permanent})',
    );
    _onErrorCallback?.call(error.errorMsg);
  }
}
