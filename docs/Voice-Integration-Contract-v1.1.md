# Voikerchat 音声実装 統合契約書 v1.1

**Date:** 2026-07-08 / **Author:** Claude / **Status:** 確定・実装の土台
**v1.1 変更点:** Gemini G1 の技術調査を反映し事実確認で補正 —
① STT/TTSパッケージの最新版を確認（pub.dev）② iOS 1分制限＋スロットリング → **Push-to-Talk確定**
③ Webはパッケージのwebモードに委譲＝**io/web facade分割は不要**に簡略化
④ iOS既定はApple送信 → **Privacy申告必須** ⑤ Android 11+ の `<queries>` 追加
⑥ scene_service確認済 → **locale は ja-JP 固定**（シーンに言語メタ無し）

仕様源: Web版（`shibuyer-jp/japanese-learning-app`）の実動音声。移植先: `shibuyer-jp/voikerchat`。

---

## 0. Phase 0 で確定した事実（実コード確認済み）

- **Web版の音声は完全無料**。`index.html` がブラウザ標準 **Web Speech API** のみ使用（STT=`SpeechRecognition`, TTS=`speechSynthesis`）。**Cloud Speech APIキー無し＝従量課金ゼロ**。
- 現行 `voikerchat` に音声実装なし（pubspec に音声パッケージ0・マイク権限なし・入力は `TextField`）→ 本契約で新規追加。
- `scene_service` にシーン言語メタは無い → 全シーン日本語会話練習。

## 1. コスト方針（確定）＝ 全経路 ¥0

| 経路 | 手段 | コスト |
|---|---|---|
| モバイル | OS内蔵（`speech_to_text` / `flutter_tts`） | **¥0** |
| Web | 同パッケージの web モード（内部で Web Speech API） | **¥0** |
| （不採用）| Google Cloud Speech STT/TTS | 従量課金・無料枠上限 → 採用しない |

## 2. G1採用結論（事実確認で補正済み）

- **STT: `speech_to_text` を採用**。ただし **iOSは1認識タスク最大約1分＋連続再起動でApple側スロットリング**（Apple公式もSTTを"ネットワーク型・利用制限あり"と明記）。→ **Push-to-Talk（押している間/タップで開始→タップで停止）＝短ターン設計を必須とする。自動再起動ループは禁止。**
- **TTS: `flutter_tts` を採用**（速度0.9・完了コールバック・ja-JP対応、要件充足）。
- **Web: 自作js interopは不採用**。両パッケージともwebモードで内部的にWeb Speech APIを呼ぶため、**そのままパッケージ経由で使う**（保守性優先）。
- **採用バージョン（pub.dev 確認 2026-07-08）:**
  - `speech_to_text: ^7.4.0`（※G1の「6.6.x」は旧版。実際の最新は7.4.0）
  - `flutter_tts: ^4.2.2`
  - Android: `compileSdkVersion 31+`。Android 11+ は Manifest に TTS の `<queries>` 宣言が必須。

## 3. 採用アーキテクチャ（v1.0から簡略化）

**io/web facade分割は不要。** `speech_to_text`/`flutter_tts` は iOS/Android/Web を単一APIで賄うため、サービスは各1ファイル（クロスプラットフォーム）でよい。
（`rewarded_ad` が facade を要したのは `google_mobile_ads` が web 非対応だったため。音声は事情が異なる。）

```
lib/services/voice/
  speech_recognition_service.dart   # 単一実装（speech_to_text をラップ）
  text_to_speech_service.dart       # 単一実装（flutter_tts をラップ）
  tts_text_cleaner.dart             # プラットフォーム非依存の純関数（共有・テスト対象）
```

- `isSupported` で UI をゲート。未対応（例: Safari/Firefox の web、非対応端末、権限拒否）なら **マイクボタンを出さずテキスト入力へフォールバック**。

## 4. 公開インターフェース契約（v1.0から不変）

> 下記シグネチャは堅牢なので Push-to-Talk 化でも変更不要。`start()` は `speech_to_text` の `listen()` をラップし、`onComplete` は onStatus=done に対応させる。

### 4-1. SpeechRecognitionService（STT）
```dart
class SpeechRecognitionService {
  bool get isSupported;          // 未対応/権限不可なら false → UIはテキストのみ
  bool get isListening;
  Future<bool> initialize();     // 一度きり初期化＋マイク/音声認識許可。使用可なら true
  Future<void> start({
    String localeId = 'ja-JP',
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onComplete,               // 自然/強制終了で1回（自動送信の合図）
    void Function(String errorCode)? onError,  // 例 'not-allowed', サービス不可
  });
  Future<void> stop();           // 停止して確定
  Future<void> cancel();         // 破棄
  void dispose();
}
```

### 4-2. TextToSpeechService（TTS）
```dart
class TextToSpeechService {
  bool get isSupported;
  bool get isSpeaking;
  Future<void> initialize();
  Future<void> speak(String text, { String localeId = 'ja-JP', double rate = 0.9, double pitch = 1.0 });
  Future<void> stop();
  void setCompletionHandler(void Function() onComplete);
  void dispose();
}
```

### 4-3. tts_text_cleaner.dart
```dart
/// 読み上げ前整形（Web版 speakText 準拠）。Markdown/記号/絵文字除去、'Score: X/10'行除去、
/// 連続改行→句点/空白、trim。
String cleanForSpeech(String raw);
```

## 5. データフロー（Push-to-Talk 版）

```
[🎤タップ=開始] → tts.stop() → stt.start(localeId:'ja-JP', onResult:入力欄へ, onComplete:自動送信判定)
[再タップ=停止] → stt.stop()      // ユーザーが明示停止（iOSの1分制限に触れる前に自分で止められる）
[onResult]     → _inputController.text = transcript   // 途中経過も反映
[onComplete]   → 入力が非空なら _sendMessage()（既存フロー）
[onError]      → 録音UI解除。'not-allowed'は許可誘導、サービス不可は「時間をおいて再試行」表示
_sendMessage() → api/chat（既存・不変）→ 応答保存 → autoRead ON なら tts.speak(cleanForSpeech(応答),'ja-JP')
```

- **自動再起動ループは作らない**（iOSスロットリング回避）。1ターン＝1認識。
- iOSで約1分に達し強制終了した場合も `onComplete` 経由で確定・送信（ユーザーには自然に見える）。
- `api/chat` は変更しない（音声はクライアント端に閉じる＝サーバーコスト増ゼロ）。
  - 契約（不変）: `POST /api/chat` `{ token, messages, sceneId, maxTokens }` → `{ content, tokensUsed }`（429=上限, 401=トークン欠落）。

## 6. chat_screen.dart 配線（Claude 担当）

- 追加 state: `_isListening`, `_isSpeaking`, `_autoRead=true`。
- サービス生成＋`initState`で`initialize()`。`dispose()`に`_stt.dispose(); _tts.dispose();`追加。
- 入力Row（既存 TextField＋送信IconButton）に **マイクIconButton** を追加（`_stt.isSupported` が true のときのみ）。停止中`Icons.mic`／認識中`Icons.stop`＋インジケータ。
- AppBar actions に **自動読み上げトグル**（`_autoRead`）。
- `_sendMessage()` 末尾（`assistantMessage`追加後）に読み上げ挿入。
- **locale は `'ja-JP'` 固定**（scene_service に言語メタ無し＝確定）。
- **UX規約: Push-to-Talk**。長押しでなくトグル（タップ開始→タップ停止）を基本とし、認識中は明示的な停止手段を常時表示。

## 7. 権限・申告（G3が雛形／Claudeが適用）

- **iOS** `Info.plist`: `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription`（文言 en/ja/fil）。
- **Android** `AndroidManifest.xml`:
  - `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
  - **TTS用 `<queries>` 宣言（Android 11+ 必須）:**
    ```xml
    <queries>
      <intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>
    </queries>
    ```
- **Privacy申告（重要・Claude担当）:**
  - iOSの`speech_to_text`は**既定でApple サーバーに音声を送信**して認識する（`requiresOnDeviceRecognition:true`で強制オンデバイス化可能だが、端末に日本語辞書が無いと失敗）。
  - → **プライバシーポリシー＆App Privacy で「音声がAppleにより処理され得る」旨を明記**。ATT+UMP のマイク権限追加と**同時実装**して二度手間回避。

## 8. 未確定・実装中に潰す（v1.1で2件解決済み）

- ✅ 解決: Web手段＝パッケージwebモード（js interop不要）。
- ✅ 解決: シーン別localeは無し → `ja-JP`固定。
- 残: iOSの1ターンUX微調整（強制終了時の見せ方・再開導線）〔実機〕。
- 残: 端末別 ja-JP TTS voice の有無・自然さ〔実機〕。未インストール時のフォールバック表示。

## 9. マージ手順（不変）
Gemini出力 → Claude が契約適合/パッケージ整合/CI観点レビュー → `feat/voice-conversation` へ統合 → CI(analyze/test) → 実機テスト → main。
コミット identity: `Takatoh Shibuyer <262262561+shibuyer-jp@users.noreply.github.com>`。
