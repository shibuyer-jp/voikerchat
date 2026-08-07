# オンボーディングと機能の発見可能性の調査（2026-08-05）

調査完了。以下、全項目の結果です。

---

# A. オンボーディングの現状

## A-1. 実装有無・初回起動時の必須表示

実装されている。`lib/main.dart:297-314` の `_resolveInitialScreen()` が起動時に必ず経由するゲートで、`is_first_launch`(`main.dart:253`)が`true`かつレベル未保存なら`OnboardingFlowScreen`(`main.dart:332`)を強制表示する。

```dart
// main.dart:303-305
final Widget nextScreen = (!firstLaunch && levelName != null)
    ? HomeScreen(userLevel: _parseLevel(levelName))
    : const OnboardingFlowScreen();
```
`OnboardingFlowScreen`(`main.dart:339-386`)の中身は診断テスト(`DiagnosticTestScreenEnhanced`)→結果画面(`LevelResultScreen`)の2画面のみ。

## A-2. 設計(Tutorial-Design-v1.0.md / Onboarding-Flow-v1.0.md)との差分

設計は**Step0〜Step5の6段階**(`Onboarding-Flow-v1.0.md:22-50`)。実装との対応:

| 設計ステップ | 内容 | 実装状況 |
|---|---|---|
| Step 0 言語選択 | 専用画面、`/api/user/init`連携 | **未実装**。専用画面なし。言語は設定画面(`SettingsScreen`)のみで変更可、初回起動時に選ばせるフローはない |
| Step 1 ウェルカム画面 | 「フィリピン人の婚約者と日本語で話そう」+「始める」ボタン | **未実装**。対応するWidgetファイルが存在しない(`lib/screens/onboarding/`配下は`diagnostic_test_screen.dart`/`diagnostic_test_screen_enhanced.dart`/`level_result_screen.dart`の3ファイルのみ) |
| **Step 2 基本操作説明**(レベル選択/シーン選択/チャット入力/設定/プロフィールの5要素をハイライト説明) | 5つのUI要素を1つずつグロー効果+説明文で見せる | **未実装**。該当ファイル・該当ロジックともに検索してゼロ件(`Welcome`/`BasicOperation`/`Step2`/`TutorialOverlay`/`Highlight`のいずれでもlib配下に一致なし) |
| Step 3 診断テスト | 3問+ヒント+スキップ | **実装済み**。`lib/screens/onboarding/diagnostic_test_screen_enhanced.dart` |
| Step 4 レベル結果 | スコア表示+レベル判定+広告再挑戦オプション | **一部実装**。`lib/screens/onboarding/level_result_screen.dart`にレベル・スコア表示はあるが、「広告を見てもう一度挑戦」オプション(0点時)のコードは見当たらない([未確認]、`level_result_screen.dart`全文を読んだ限り広告ボタンなし) |
| Step 5 シーン選択(推奨シーン最上位+グロー効果、専用の「シーン開始/後で選ぶ」導線) | オンボーディング内で完結するシーン選択画面 | **簡略化して実装**。`LevelResultScreen`の「続けてシーンへ」ボタン(`main.dart:364-368`)は専用画面を経ずに`HomeScreen`へ遷移し、`HomeScreen`のデフォルトタブ`SceneSelectionScreen`が実質のシーン選択を担う。推奨シーンは`sceneSectionRecommended`セクション見出しで表示されるが(`scene_selection_screen.dart:279-281`)、設計にある「グロー効果」は未確認 |

**最重要の欠落はStep 2**。背景フィードバックの「操作がわからない、何をしてよいか戸惑う」は、まさにこのStep 2(UI操作説明)が担うはずだった内容であり、コード上一切存在しない。

## A-3. スキップ可否・再表示導線

診断テスト自体は各問「わかりません」でスキップ可能(`diagnostic_test_screen_enhanced.dart:94-100`の`_handleSkip`)。ただし**オンボーディングフロー全体をスキップする導線はない**(Step0/1/2が存在しないため「スキップ」対象自体がない)。

再表示導線: **存在しない**。`is_first_launch`は`_handleLevelResultContinue`(`main.dart:358-361`)で`false`に永続化されるだけで、設定画面等から再度呼び出す仕組みは見当たらない([未確認: 完全な網羅的検索はしていないが、`settings_screen.dart`内に該当ボタンは確認できず]）。

## A-4. `lib/models/onboarding.dart` の関係

同一ファイル内に**2つの異なる役割**が同居している:
- `OnboardingState`クラス(`onboarding.dart:8-72`): **生きている**。`main.dart:11`でimportされ、`_OnboardingFlowScreenState.currentState`(`main.dart:340,345`)として実際に診断結果を保持する。
- `SceneDefinition`クラス(`onboarding.dart:75-210`、13シーン定義): **デッドコード**。`grep`で`lib/`配下の参照は定義ファイル自身のみ(1件)。実際のシーン管理は`lib/services/scene_service.dart`(18シーン、CLAUDE.md記載通り)が担っており、`SceneDefinition.getAllScenes()`は呼び出し箇所ゼロ。

---

# B. 各機能のUI導線

## B-1. ヒント機能(hint)

- **起動導線**: チャット画面下部、メッセージ入力欄の右隣にある電球アイコンボタン(`chat_screen.dart:1047-1054`)。常時表示(送信中のみ無効化)。
```dart
// chat_screen.dart:1044-1054
// T-36: 次に言えそうな例文+英訳のヒント。会話クォータは消費しない。
// 「ひらめき」の定番色=黄色の塗りつぶし電球で視認性を上げる
// (TestFlight目視フィードバック: 気づかれにくい)。
IconButton(
  icon: Icon(Icons.lightbulb, color: Colors.amber.shade600),
  tooltip: l.hintButtonTooltip,
  onPressed: _isSending ? null : _showHint,
),
```
- **ラベル**: ツールチップのみ(ボタン自体にテキストラベルなし)。ja: 「ヒント: 次に何て言おう?」/ en: "Hint: what could I say next?"(`app_ja.arb:121`, `app_en.arb:531`)。
- **初回説明**: **なし**。`hint_sheet.dart`に初回利用時の説明・ハイライトは見当たらない。
- **常時/条件付き**: 常時表示。
- **特筆事項**: 上記コメント自体が**過去のTestFlight目視フィードバックで「気づかれにくい」と既に指摘され**、対策として色をアンバーの塗りつぶしに変更した経緯を示す。それでも背景データで4%の利用率にとどまっており、色変更だけでは不十分だったことを示唆する。

## B-2. 辞書機能(define)

- **起動導線**: **常時表示のボタンは存在しない**。AIメッセージの本文(`_buildAssistantMessageText`, `chat_screen.dart:1260-1302`)は`SelectableText`で、ユーザーが**テキストを長押し選択**すると出るiOS/Android標準のテキスト選択ツールバーに、カスタムのコンテキストメニュー項目「意味を調べる」が先頭挿入される形でのみ到達する。
```dart
// chat_screen.dart:1269-1280
if (selectedText.trim().isNotEmpty) {
  buttonItems.insert(
    0,
    ContextMenuButtonItem(
      label: AppLocalizations.of(context).lookUpMeaning,
      onPressed: () {
        ContextMenuController.removeAny();
        editableTextState.hideToolbar();
        _showWordLookup(selectedText.trim(), message.content);
      },
    ),
  );
}
```
- **ラベル**: 「意味を調べる」/ "Look up meaning"(`app_ja.arb:104`, `app_en.arb:463`)。
- **初回説明**: なし(`word_lookup_sheet.dart`にも初回案内なし)。
- **常時/条件付き**: 条件付き(テキスト選択+選択範囲が空でない場合のみメニューに出現)。
- **到達難易度**: **到達困難と判断する**。「長押し→ドラッグで選択範囲確定→出現したツールバーをスクロール/確認→『意味を調べる』を選ぶ」という、モバイルのテキスト選択操作に慣れていないと発見しにくい多段階操作。ボタンやアイコンとして画面上に visibleな入口が一切ない。背景データの「30日で9回」はこの導線の弱さと整合する。

## B-3. 言い直し復習(recap)

- **起動導線**: ユーザーが能動的に押せるボタンは存在しない。`chat_screen.dart`の「⋮」(more_vert)メニュー(`chat_screen.dart:878-881`, `_showSessionOptions`)を開き、その中の「会話を消去」(`clearConversation`, line 1124-1158)または「退出する」(`exitConversation`, line 1160-1173)を選んだ場合に限り、かつユーザー発話が3往復以上(`_vocabSummaryMinUserTurns = 3`, `chat_screen.dart:1359`)であれば`_maybeShowVocabSummary()`(line 1361-)が呼ばれ、その中の`VocabSummarySheet`(`vocab_summary_sheet.dart`)の一部として表示される。**単独機能として明示的に呼び出す手段はない**。
```dart
// chat_screen.dart:1147-1150 (「会話を消去」選択時)
if (confirm == true && _userId != null) {
  await _maybeShowVocabSummary();
  ...
```
- **ラベル**: シート内のセクション見出しとしてのみ登場。「今日の言い直し」/ "Today's rephrasing"(`vocab_summary_sheet.dart:238`, `app_ja.arb:131`)。機能名「recap」や「言い直し復習」という単語自体は、この見出し以外どこにもユーザーへ露出しない。
- **初回説明**: なし。
- **常時/条件付き**: 条件付き(3往復以上 **かつ** 「⋮」メニュー経由の明示的な会話終了操作、の両方が必要)。単純にアプリを閉じる/タブ切替/戻るボタンでは発火しない。
- **到達難易度**: **到達困難**。「⋮」という一般的な意味を持たないアイコンの中に、機能名の言及すらない状態で埋め込まれている。

## B-4. 今日の単語(vocab_summary)

recapと**全く同じ導線・同じ発火条件**(同一の`VocabSummarySheet`、同一の`_maybeShowVocabSummary()`呼び出し)。`vocab_summary_sheet.dart:42-51`で`recapService.getRecap()`と`vocabSummaryService.getSummary()`を`Future.wait`で並行取得し同じシートに表示するため、ユーザー到達可能性の評価はrecapと同一(到達困難)。ラベル「今日の単語」/ "Today's words"(`vocab_summary_sheet.dart:272`, `app_ja.arb:127`)。

## B-5. 音声読み上げ(cloud_tts / auto-read)

2つの異なる機能が存在する:

1. **自動読み上げON/OFFトグル**: AppBar常時表示のスピーカーアイコン(`chat_screen.dart:869-874`)。
```dart
if (_ttsReady)
  IconButton(
    icon: Icon(_autoRead ? Icons.volume_up : Icons.volume_off),
    tooltip: l.voiceAutoRead,
    onPressed: () => setState(() => _autoRead = !_autoRead),
  ),
```
ラベル: 「自動読み上げ」/ "Auto-read"。常時表示(`_ttsReady`成立時)。初回説明なし。

2. **高品質ボイス(クラウドTTS)の解放状態**: 「⋮」メニュー内の`ListTile`(`chat_screen.dart:1101-1119`)。無料ユーザーは広告視聴で当日のみ解放。
```dart
title: Text(
  (_isPremium || _cloudTtsUnlockedToday)
      ? AppLocalizations.of(context).cloudVoiceActiveTooltip   // "本日は高品質ボイス有効"
      : AppLocalizations.of(context).cloudVoiceLockedTooltip,  // "🎧 高品質ボイス — 広告を見て今日解放(プレミアムは毎日)"
),
```
これも「⋮」メニュー内(常設UIから意図的に外された旨のコメントが`chat_screen.dart:875-877`にあり)。低頻度操作のためと明記されているが、機能の存在自体に気づく機会も同様に減っている。

## B-6. 英訳・翻訳機能

**存在しない**。`translate`/`Translat`で検索した結果、生成済みARB自動生成ファイル(`l10n/*.dart`, `*.arb`)以外にヒットなし。AIキャラクターの返答全文を英語/タガログ語に訳す機能・対訳表示機能は実装されていない。日本語理解を助ける機能は、Cで述べるふりがな(発音補助)と、B-2の辞書機能(単語単位の英訳/タガログ語訳)のみ。

---

# C. 「日本語のみで理解できない」への既存の答え

## C-1. AI返答を英語/タガログ語で理解する機能の有無

**全文翻訳・対訳表示は存在しない**。存在するのは以下の2つのみ、いずれも部分的:
- **ふりがな**(`furiganaEnabled`): 発音の補助であり、意味理解の補助ではない(漢字の読み方が分かっても意味は分からない)。
- **辞書機能(define)**: 選択した単語1つに対し`meaning_en`/`meaning_fil`を返す(`api/define.ts:25`のプロンプト仕様)。ただしB-2で述べた通り到達困難。

## C-2. `furiganaEnabled` のON/OFF

デフォルトは**ON**(`true`)。
```dart
// lib/screens/chat_screen.dart:84
bool _furiganaEnabled = true;
// lib/screens/settings_screen.dart:29
bool _furiganaEnabled = true;
```
設定画面の`SwitchListTile`(`settings_screen.dart:227-233`)で切替可能。`LearnerPreferencesService`で永続化。トグル自体のラベルは「ふりがな表示」/ サブタイトル「AIの返答の漢字にふりがなを表示します(例: 漢字(かんじ))」(`app_ja.arb:271-272`)であり、**意味理解ではなく読み方の補助である旨が明記されている**(意味理解機能と誤認させる文言ではない)。

## C-3. UI導線

設定画面(`SettingsScreen`)自体への到達導線: `scene_selection_screen.dart:263-267`の歯車アイコン(`Icons.settings_outlined`)から。
```dart
// scene_selection_screen.dart:263-267
icon: const Icon(Icons.settings_outlined),
...
MaterialPageRoute(builder: (_) => const SettingsScreen()),
```
常時表示、初回説明なし。

**結論**: 「キャラの返答が日本語のみで理解できない」というフィードバックに対する現行実装の答えは、実質的に**辞書機能(define)のみ**であり、かつその到達導線はB-2で述べた通り最も発見しにくい実装(長押し選択メニュー)になっている。ふりがなは無関係(読み方の補助であり意味理解の補助ではない)。

---

# D. 離脱ポイントの推定

初回起動〜チャット開始までの画面遷移(コード上のゲート、`main.dart:297-314`および関連画面から復元):

```
① スプラッシュ相当(FutureBuilder読み込み中、main.dart:318-325)
        ↓
② AIデータ同意画面(consentAccepted=false の場合。ai_data_consent_screen.dart)
        ↓
③ 診断テスト(3問、diagnostic_test_screen_enhanced.dart)
        ↓
④ レベル結果画面(level_result_screen.dart)
        ↓
⑤ HomeScreen(デフォルトタブ = シーン選択画面、scene_selection_screen.dart)
        ↓ (シーンをタップ)
⑥ チャット画面(chat_screen.dart、AIキャラのオープニング発話から開始)
```

**設計(Onboarding-Flow-v1.0.md)にあったStep0(言語選択)・Step1(ウェルカム)・Step2(操作説明)は存在しないため上記フローには現れない。**

各画面での停止しうる箇所:

- **②AIデータ同意画面**: 同意ボタンを押さないと先に進めない**必須ゲート**。文言が「第三者(Anthropic/OpenAI)へのデータ送信」等の専門的な内容を含む場合(内容は[未確認]、`internal-docs/DECISIONS.md` 2026-08-03の記述からAI開示同意目的と推測)、日本語学習アプリだと思って来たユーザーが法的文言に戸惑い離脱する可能性がある。
  - **Android Build 16には未収録**(`DECISIONS.md` 2026-08-04(続々)記載の通り、PR #36マージ前のコミットでビルドされているため)。コード自体にプラットフォーム分岐はなく(`ai_data_consent_screen.dart`にPlatform判定なし)、**ビルドタイミングの問題**であり設計上Androidを除外しているわけではない。次回Android配信(Build 18)で収録される見込み。
- **③診断テスト**: 「基本操作説明(Step2)」を経ずにいきなり日本語能力を問う3問(N4〜N2)から始まる。ウェルカムの温かい導入(設計のStep1)なしにテストが始まるため、初回起動直後に「試験を受けさせられている」体感になりうる。テスターの「戸惑う」というフィードバックと整合しうる([未確認]: 因果関係の断定はできない)。わからない問題への「わかりません」選択肢の視認性は[未確認]。
- **④レベル結果画面**: 一方向のボタンのみで低リスク。
- **⑤シーン選択**: 最大18シーンから選ぶ必要があり、初見でどれを選べばよいか判断材料(推奨シーンの見出しはあるが、視覚的な強調=グロー効果は[未確認])が弱い可能性。
- **⑥チャット画面**: AIキャラの最初の発話は日本語で開始される(オープニング発話、`_insertOpeningLineIfNeeded`)。この時点でBで述べた通り、ヒント/辞書/読み上げいずれの補助機能にも初回説明が無く、ユーザーは「日本語だけで話しかけられて、何をすればいいか分からない」状態に置かれる。これは今回のテスターフィードバック2件(「日本語のみで理解できない」「操作がわからない」)の双方に直結する箇所と考えられる([未確認]: 実際の離脱ログ・行動データによる裏付けはしていない、コード構造からの推定)。

---

## [未確認] まとめ
- Step4「広告を見てもう一度挑戦」オプションが本当に未実装か(`level_result_screen.dart`全文には見当たらないが、他ファイルでの補完実装がないかは網羅的探索していない)
- オンボーディング再表示導線が本当に皆無か(設定画面以外の全画面は精査していない)
- Step5のシーン選択における「グロー効果」相当の視覚的強調の有無
- AIデータ同意画面の実際の文言内容とその離脱率への影響
- 診断テストの「わかりません」選択肢の視認性
- Dの各画面での実際の離脱率・滞在時間(コードからは判断不可、分析ログが必要)
- recapが30日で0回である一方vocab_summaryとの呼び出し条件が同一である理由(呼び出し自体は常に対になるはずだが、実際の成功率の差はコードからは判断できない)

コードの変更・commit・push は行っていません。
