# Voikerchat 音声実装 統合契約書 v1.0

**Date:** 2026-07-08 / **Author:** Claude (Phase 0 成果) / **Status:** 確定・実装の土台

この文書は「Web版（`shibuyer-jp/japanese-learning-app`）で実動している音声機能」を仕様源として、
現行 Flutter版（`shibuyer-jp/voikerchat`）に音声（会話）を移植するための**唯一の土台**です。
Gemini に投げる G1–G5 は、すべてこの契約に沿わせます（丸腰で書かせない）。

---

## 0. Phase 0 で確定した事実（実コード確認済み）

- **Web版の音声は完全無料**。`index.html` がブラウザ標準の **Web Speech API** のみを使用:
  - STT（音声→文字）: `window.SpeechRecognition || window.webkitSpeechRecognition`（`lang = 'ja-JP'|'en-US'`, `interimResults=true`, `continuous=false`）
  - TTS（文字→読み上げ）: `window.speechSynthesis` + `SpeechSynthesisUtterance`
  - **Google Cloud Speech API のキーは一切なし**＝従量課金ゼロ。「Googleの無料枠」の正体はこれ（=ブラウザ内蔵の無料API。Chromeでは認識がGoogleエンジンで動くだけ）。
- 初期Flutter版（`japanese-learning-app-flutter`）は読み上げに `flutter_tts`（OS内蔵）を使用済み＝モバイルでも**無料で実現可能**。
- 現行 `voikerchat` リポジトリには音声実装なし（pubspec に音声パッケージ0・マイク権限なし・入力は `TextField`）。→ 本契約で新規追加。

## 1. コスト方針（確定）

| 経路 | 手段 | コスト |
|---|---|---|
| モバイル（iOS/Android） | OS内蔵エンジン（`speech_to_text` / `flutter_tts`） | **¥0**（クラウド非経由） |
| Web | ブラウザ Web Speech API | **¥0** |
| （不採用）高品質路線 | Google Cloud Speech-to-Text / Text-to-Speech | 従量課金・無料枠は月間上限あり → **今回不要** |

→ **Web版と同等を目指す＝全経路 ¥0。** クラウド有料APIは採用しない。

## 2. Web版の音声フロー（＝移植する挙動の正）

1. マイクボタン押下 → 進行中TTSを `cancel()` → `recognition.start()` → ボタン `🎤→⏹️`、入力欄プレースホルダ「聞いています…」。
2. `interimResults` を逐次 入力欄へ反映。
3. `onend`（話し終わり）: 録音UI解除 → 入力にテキストあれば **自動送信**。
   - ※Web版は日本語モード時に採点用プロンプトへ変換していたが、**voikerchatはシーン会話が主目的なので採点変換はしない**（そのまま送信）。採点はシーン設計側の責務。
4. `onerror`（`not-allowed`）: マイク不許可アラート。
5. アシスタント応答受信後、`autoRead` がONなら本文をクリーニングして `speak()`（**既定ON**）。
   - クリーニング: Markdown除去・記号除去・`Score: X/10` 行除去・絵文字除去・改行を句点/空白へ。

## 3. 採用アーキテクチャ（既存 facade 方式に完全準拠）

既存 `rewarded_ad_service.dart` と同じ**条件付きexport facade**で実装する。利用側（`chat_screen`）は facade 1本だけ import。

```
lib/services/voice/
  speech_recognition_service.dart      # facade（条件付き export）
  speech_recognition_service_io.dart   # モバイル実装（speech_to_text）
  speech_recognition_service_web.dart  # Web実装（Web Speech API / js interop）
  text_to_speech_service.dart          # facade（条件付き export）
  text_to_speech_service_io.dart       # モバイル実装（flutter_tts）
  text_to_speech_service_web.dart      # Web実装（speechSynthesis / js interop）
  tts_text_cleaner.dart                # プラットフォーム非依存の純関数（共有・テスト対象）
```

facade の中身（`rewarded_ad_service.dart` と同型）:
```dart
// speech_recognition_service.dart
export 'speech_recognition_service_io.dart'
    if (dart.library.html) 'speech_recognition_service_web.dart';
```

## 4. 公開インターフェース契約（io/web 両実装が必ず満たす）

> 抽象クラスではなく「両ファイルが同名 class として実装すべき公開API」。既存 `RewardedAdService` の `isSupported`/`isReady`/`dispose()` 方式に合わせる。

### 4-1. SpeechRecognitionService（STT）

```dart
class SpeechRecognitionService {
  /// この環境で音声認識が使えるか（未対応OS/ブラウザ・権限不可なら false）。
  /// false の場合、UI はマイクボタンを出さずテキスト入力のみにフォールバック。
  bool get isSupported;

  /// 現在リッスン中か。
  bool get isListening;

  /// 一度きりの初期化＋マイク/音声認識の許可要求。使用可能なら true。
  Future<bool> initialize();

  /// リッスン開始。Web版 onresult/onend/onerror を callback で再現する。
  /// - onResult: 逐次結果（isFinal=false は途中経過、true は確定）。入力欄へ反映。
  /// - onComplete: 自然終了（Web onend 相当）。呼び出し側はここで自動送信を判断。
  /// - onError: errorCode（例 'not-allowed'）。
  Future<void> start({
    String localeId = 'ja-JP',
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onComplete,
    void Function(String errorCode)? onError,
  });

  /// 停止して確定（onComplete が呼ばれる）。
  Future<void> stop();

  /// 中断（確定させず破棄）。
  Future<void> cancel();

  void dispose();
}
```

### 4-2. TextToSpeechService（TTS）

```dart
class TextToSpeechService {
  bool get isSupported;
  bool get isSpeaking;

  Future<void> initialize();

  /// text を読み上げる。呼び出し前に必ず tts_text_cleaner で整形済みの前提。
  /// localeId 既定は 'ja-JP'（アシスタントの日本語応答を読むため）。
  Future<void> speak(
    String text, {
    String localeId = 'ja-JP',
    double rate = 0.9,   // 学習用に少しゆっくり（Web版 0.9 準拠）
    double pitch = 1.0,
  });

  /// 読み上げ停止（マイク起動時・画面破棄時に呼ぶ）。
  Future<void> stop();

  /// 読み上げ完了コールバック（次アクション用）。
  void setCompletionHandler(void Function() onComplete);

  void dispose();
}
```

### 4-3. tts_text_cleaner.dart（純関数・共有）

```dart
/// 読み上げ前のテキスト整形（Web版 speakText 準拠）。
/// Markdown（**bold**, *italic*, #, 箇条書き, [link](url), `code`）除去、
/// 絵文字除去、'Score: X/10' 行除去、連続改行→句点/空白、trim。
String cleanForSpeech(String raw);
```

## 5. データフロー（音声→応答→読み上げ）

```
[🎤タップ] → tts.stop()
          → stt.start(localeId: sceneLocale, onResult: 入力欄へ, onComplete: 自動送信判定)
[onResult] → _inputController.text = transcript
[onComplete] → 入力が非空なら _sendMessage()（既存フロー）
_sendMessage() → api/chat（既存・変更なし）→ アシスタント応答保存
          → autoRead が ON なら tts.speak(cleanForSpeech(応答), localeId:'ja-JP')
```

- **`api/chat` は変更しない**（テキストのまま）。音声はクライアント端で STT/TTS に閉じる＝サーバーコスト増なし。
- リクエスト/レスポンス契約（既存・不変）: `POST /api/chat` body `{ token, messages, sceneId, maxTokens }` → `{ content, tokensUsed }`（429=レート上限, 401=トークン欠落）。

## 6. chat_screen.dart への配線（Claude が担当・Gemini に渡さない）

- 追加 state: `_isListening`, `_isSpeaking`, `_autoRead=true`。
- サービス生成: `final _stt = SpeechRecognitionService(); final _tts = TextToSpeechService();`（`initState` で `initialize()`）。
- 入力 Row（既存 TextField + 送信 IconButton）に **マイク IconButton** を追加（`_stt.isSupported` が true のときのみ表示）。
  - アイコン: 停止中 `Icons.mic` / リッスン中 `Icons.stop`（録音インジケータ）。
- AppBar actions に **自動読み上げトグル**（`_autoRead`）を追加。
- `_sendMessage()` 末尾（`assistantMessage` 追加後）に読み上げ呼び出しを挿入。
- `dispose()` に `_stt.dispose(); _tts.dispose();` を追加。
- ロケール: 当面 `'ja-JP'` 固定（シーンが日本語会話練習のため）。将来シーン別言語対応時は `widget.sceneData['locale'] ?? 'ja-JP'`。〔※シーンに言語メタがあるか要確認〕

## 7. 権限（Gemini G3 が雛形・Claude が最終適用）

- **iOS** `ios/Runner/Info.plist`:
  - `NSMicrophoneUsageDescription`
  - `NSSpeechRecognitionUsageDescription`
  - 文言は en/ja/fil（`InfoPlist.strings` ローカライズ）。
- **Android** `android/app/src/main/AndroidManifest.xml`:
  - `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
  - ランタイム権限は `speech_to_text` の `initialize()` 経由で要求。
- **App Privacy 整合**（Claude 担当）: マイク使用を宣言。ATT+UMP のマイク権限追加と**同時実装**して二度手間回避。
  - 補足: OS内蔵STT/TTSはクラウド非経由のため「データ収集」区分は最小。ただし iOS の音声認識はデバイス/iOSバージョンによりApple側処理になる場合あり〔G1で要確認〕。

## 8. パッケージ（G1 が最終バージョン確認）

- `speech_to_text`（STT・iOS/Android・web対応あり）
- `flutter_tts`（TTS・iOS/Android・web対応あり）
- ※両者とも web 対応を持つため、Web facade はこれらの web モードで足りる可能性あり。
  js interop 手書きと比較してどちらが安定かは **G1 で検証** → Claude が最終決定。

## 9. 未確定・要検証（実装中に潰す）

1. iOS `speech_to_text` の 1セッション認識時間上限・連続会話時の再起動要否〔G1/実機〕。
2. 端末による ja-JP 音声（TTS voice）の有無・自然さ〔G1/実機〕。
3. Web facade を「パッケージ web モード」か「js interop 手書き」か〔G1 → Claude決定〕。
4. シーンデータに言語メタ（locale）が存在するか〔Claude が scene_service 確認〕。

## 10. マージ手順（不変）

Gemini出力 → Claude が「契約適合・パッケージ整合・CI観点」レビュー → feature branch（`feat/voice-conversation`）へ統合 → CI（analyze/test）→ ユーザー実機テスト → main。
Voikerchat コミット identity: `Takatoh Shibuyer <262262561+shibuyer-jp@users.noreply.github.com>`。
