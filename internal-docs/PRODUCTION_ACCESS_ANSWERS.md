# Google Play 製品版アクセス申請 — 回答文(提出用完成版)

**作成日**: 2026-08-12
**位置づけ**: `internal-docs/PRODUCTION_ACCESS.md`3節の回答案(ドラフト・判断根拠)を、申請当日にそのまま貼り付けられる完成形として独立させたもの。**本書はドラフトではなく完成版**。手順・チェックリスト・判断根拠は`internal-docs/PRODUCTION_ACCESS.md`側を参照すること。

---

## 運用ルール(申請開始前に必ず読むこと)

- 3セクション全ての回答を本書から用意してから申請を開始する。**ブラウザのタブを切り替えて確認作業をしない**(セクションで「破棄」または「次へ」を押さずに離脱すると入力は保存されない)
- 各セクションは「貼り付け → Next」で進む。**Part 3の最後だけは「Apply」で提出確定**(Next のつもりで押すと申請が確定するため要注意)
- 文字数制限は**300字**(2026-08-14申請時に確認)。記述式の各設問に**標準版**と**短縮版**を併記していたが、標準版はいずれも300字を超えるため、実提出では6問とも**短縮版**(いずれも300字以内、最大189字)をそのまま使用した
- 日本語UIを想定した**日本語版**と、英語表示だった場合に備えた**英語版**を両方用意した。実際に開いた申請フォームの表示言語に合わせて選ぶこと
- 選択式2問(Part 1①・Part 2③)は、選択肢そのものが申請フォームを開くまで確認できない(`internal-docs/PRODUCTION_ACCESS.md`2節「質問のプレビューの実態」参照)。本書には選ぶべき"方向性"のみ記載する
  - **Part 1①(テスター募集の難易度)**: 「難しかった」側の選択肢を選ぶ
  - **Part 2③(初年度インストール数見込み)**: 提示された選択肢のうち最も低い範囲、または下から2番目を選ぶ

### 実際に提出した回答(2026-08-14、300字版)

申請フォームは日本語UIで表示され、文字数上限は300字だった。記述式6問はいずれも下記「日本語版(短縮)」をそのまま使用した(標準版は300字を超えるため未使用)。提出した6本の全文を記録として残す。

1. **Part 1② テスト中のエンゲージメント**(189字)
```
テスターは全18シーンの会話機能・通知・オンボーディング・辞書機能を中心に利用した。テスター構成は実ターゲット層(フィリピン在住、配偶者のネットワーク経由)とテスター管理サービス経由(日本国内、動作確認中心)の2系統。Premium購読フローは開発者本人が実購入で検証済みで機能しているが、Google Play収益レポートで確認した結果、テスター自身による購入実績はなかった。
```

2. **Part 1③ フィードバックの要約と収集方法**(177字)
```
フィードバックは①配偶者経由のフィリピン側テスター(Q&A形式)、②Play Console投稿、③テスター管理サービスの3経路で収集した。①からは無料枠不足・日本語応答のみで初級者に難しい・現状では課金段階に至らない、の3点が挙がった。②は動作確認中心の肯定的評価4件。①を受け無料枠を10/日へ引き上げ、オンボーディングを拡充し、辞書機能を追加した。
```

3. **Part 2① 想定ユーザー層**(93字)
```
フィリピン人パートナーを持つ、または日本での就労・生活のために日本語を学ぶフィリピン人学習者(成人、初級〜中級)。日常会話・敬語に加え、介護・医療現場の実務日本語への実用ニーズを持つ層。
```

4. **Part 2② アプリが提供する価値**(94字)
```
AIキャラクターとのシーン別会話練習(全18シーン)で実践的な日本語運用能力を養える。音声入力・読み上げ対応、会話中の難語をタップで確認できる辞書機能、学習統計による進捗の可視化を備える。
```

5. **Part 3① クローズドテストで学んだことに基づいて加えた変更**(155字)
```
テスターの指摘を受け、無料枠を10/日へ引き上げ、オンボーディングを拡充し、辞書機能を追加した。開発側でも統計画面・通知履歴・同意画面・オフライン起動・Premium判定・返金時の剥奪処理など複数の不具合を発見・修正した。テスト期間中にBuild 16/18/21の計3回アップデートを配信し継続的に改善した。
```

6. **Part 3② 製品版の準備が整ったと判断した根拠**(167字)
```
CI/pre-pushフックによる自動テストを開発プロセスに組み込み、Android Vitalsではクラッシュ・ANRの記録が期間中0件、決済基盤(RevenueCat・RTDN・返金処理)の整備を完了、プライバシー/データセーフティの整合確認、ポリシーステータスに問題なしを確認しており、製品版としての準備が整ったと判断している。
```

選択式2問の実際の選択: Part 1①(テスター募集の難易度)は「難しい」、Part 2③(初年度インストール数見込み)は「0〜1万」を選択した。詳細はDECISIONS.md 2026-08-14参照。

### 記述上の共通ルール

- 開発者自身の気づきを「テスターからの指摘」と偽って書かない(`DECISIONS.md` 2026-07-29の教訓)
- 未実装の改善を「加えた変更」として書かない
- 断定できない事実に断定的な表現を使わない(特にAndroid Vitalsのクラッシュ件数を「クラッシュ報告ゼロ」と書かない)

---

## Part 1② テスト中のエンゲージメント

### 確認結果(2026-08-12、確定)

Play Consoleの定期購入レポート(合計定期購入数/新規定期購入/解約された定期購入)をCSVエクスポートして確認した結果、2026年2月8日〜8月8日の182日間、全日程ですべて0件だった[確認済 2026-08-12、Play Console収益レポートのCSVエクスポート]。**テスター自身による定期購入の購入実績はゼロで確定**した(データは8/8までで8/9〜8/12の4日分は反映遅延により未収録だが、テスト期間の大半をカバーしており結論に影響しない)。以下の本文はこの確定事実に基づく完成版。詳細は`internal-docs/DECISIONS.md` 2026-08-12参照。

### 日本語版(標準)

```
テスターは、全18シーンにわたるAIキャラクターとの音声/テキスト会話機能、通知機能、初回オンボーディング、会話中の難語をタップして意味を確認できる辞書機能を中心に利用した。

テスターの構成は2系統に分かれる。①配偶者のネットワークを通じて確保した、フィリピン在住の実ターゲット層(日本語学習者)、②テスター管理サービスを通じて確保した、主に日本国内在住のテスター。後者は日本語UIでの動作確認が中心であり、学習用途としての利用実態は本番想定ユーザーとは異なる。

課金(Premium)フローについては、RevenueCatのAndroid用APIキーをBuild 18以降のビルドに投入済みで購読ボタンは有効化されており、開発者本人がPremium定期購入を実際に購入し、購入からエンタイトルメント反映・機能解放までの一連のフローを検証済みである。一方、Google Playの収益レポートで確認したところ、テスト期間中、テスター自身による定期購入の購入実績はなかった。統計画面等のPremium限定機能についても、テスター自身がPremium状態でこれらを利用した実績はない。テスターの利用は主に無料枠での会話練習と機能の動作確認が中心だった。
```

### 日本語版(短縮)

```
テスターは全18シーンの会話機能・通知・オンボーディング・辞書機能を中心に利用した。テスター構成は実ターゲット層(フィリピン在住、配偶者のネットワーク経由)とテスター管理サービス経由(日本国内、動作確認中心)の2系統。Premium購読フローは開発者本人が実購入で検証済みで機能しているが、Google Play収益レポートで確認した結果、テスター自身による購入実績はなかった。
```

### English (standard)

```
Testers primarily used the AI conversation feature (text/voice) across all 18 scenes, the notification feature, the first-run onboarding flow, and the in-conversation dictionary feature (tap a difficult word to see its meaning).

Our testers fall into two groups: (1) testers based in the Philippines, recruited through my spouse's personal network, who represent our actual target audience of Japanese-language learners, and (2) testers recruited through a third-party tester-management service, mostly based in Japan. The second group's usage was primarily focused on functional verification in the Japanese-language UI, and their usage pattern differs from that of our intended learners.

Regarding the premium purchase flow: the RevenueCat Android API key has been included in builds since Build 18, and the subscribe button is fully functional -- I (the developer) personally completed a real purchase and verified the end-to-end flow from purchase through entitlement activation and feature unlock. Having reviewed Google Play's revenue reports, however, no tester completed an actual subscription purchase during the testing period. Similarly, no tester used premium-only features (such as the statistics dashboard) while in a premium state. Tester usage was concentrated on free-tier conversation practice and functional checks.
```

### English (short)

```
Testers mainly used the AI conversation feature across all 18 scenes, notifications, onboarding, and the dictionary feature. Testers fall into two groups: real target-audience testers in the Philippines (via my spouse's network), and testers from a management service in Japan focused on functional checks. The premium purchase flow works end-to-end and was verified by the developer, but Google Play's revenue reports confirm no tester made an actual purchase.
```

---

## Part 1③ フィードバックの要約と収集方法

### 日本語版(標準)

```
フィードバックは3つの経路で収集した。①配偶者を通じたフィリピン在住テスターへの依頼(Q&A形式、全5問: 最も使ったシーン/難易度/混乱した点/課金意向/一つ変えるなら)。②Play Console「評価とレビュー→テストのフィードバック」からの投稿。③テスター管理サービス経由。

①フィリピン側テスターからは、全体の総意として次の3点が挙がった。(1)無料枠が1日5メッセージでは練習量として不足している、(2)AIキャラクターの返答が日本語のみのため初級者には理解が難しい、(3)現状のままでは有料プランに課金する段階には至っていない。

②Play Console経由では4件の投稿があった(Build 18時点3件・Build 13時点1件)。Android 14〜16の複数端末での動作を確認でき、「動作が軽い」「UIが整っている」といった肯定的な評価が中心だった。ただしこれらは動作確認中心の評価であり、学習内容そのものへの評価は含まれていない。

①の指摘を受け、無料枠を1日5→10メッセージ(広告視聴で最大20)へ引き上げ、初回起動時のオンボーディングを拡充し、会話中の難語をタップして意味を調べられる辞書機能を追加した。(2)への恒久対応(タップで英訳を表示する機能)は方針を決定済みだが未実装である。
```

### 日本語版(短縮)

```
フィードバックは①配偶者経由のフィリピン側テスター(Q&A形式)、②Play Console投稿、③テスター管理サービスの3経路で収集した。①からは無料枠不足・日本語応答のみで初級者に難しい・現状では課金段階に至らない、の3点が挙がった。②は動作確認中心の肯定的評価4件。①を受け無料枠を10/日へ引き上げ、オンボーディングを拡充し、辞書機能を追加した。
```

### English (standard)

```
We collected feedback through three channels: (1) a structured Q&A survey sent to our Philippines-based testers through my spouse's network (5 questions: most-used scene, difficulty level, points of confusion, willingness to pay, one thing to change), (2) submissions via Play Console's "Ratings and reviews -> Test feedback," and (3) feedback via our tester-management service.

From (1), the consensus among Filipino testers highlighted three points: the free tier's daily message limit (5 messages/day) felt insufficient for practice; the AI character's replies being Japanese-only made comprehension difficult for beginners; and testers did not yet feel ready to pay for a premium subscription given the app's current state.

From (2), we received 4 submissions via Play Console (3 from Build 18, 1 from Build 13), confirming functionality across Android versions 14-16 on multiple devices, with generally positive comments about performance and UI. These were primarily functional-verification comments and did not include evaluation of the learning content itself.

In response to (1), we raised the free-tier daily message limit from 5 to 10 (up to 20 with a rewarded ad), expanded the first-run onboarding flow, and added an in-conversation dictionary feature (tap a difficult word to see its meaning). A permanent fix for the Japanese-only-response issue (an on-demand English translation feature) has been decided on but is not yet implemented.
```

### English (short)

```
Feedback came from three channels: a spouse-network survey of Philippines-based testers, Play Console submissions, and our tester-management service. Filipino testers cited an insufficient free-tier limit, Japanese-only AI replies being hard for beginners, and not yet being ready to pay. Play Console yielded 4 positive functional-check reviews. In response, we raised the daily free limit to 10, expanded onboarding, and added a dictionary feature.
```

---

## Part 2① 想定ユーザー層

### 日本語版(標準)

```
主な想定ユーザーは、フィリピン人のパートナー(配偶者・婚約者)を持ち、日常生活でのコミュニケーションのために日本語を学びたい方、および日本での就労・生活のために日本語を学びたいフィリピン人学習者である。年齢層は成人が中心で、初級〜中級レベルの学習者を想定している。日常会話・敬語といった一般的なニーズに加え、介護・医療現場での実務日本語(プレミアムシーン)など、実際の生活・就労場面に直結する実用的なニーズを持つ層を主なターゲットとしている。
```

### 日本語版(短縮)

```
フィリピン人パートナーを持つ、または日本での就労・生活のために日本語を学ぶフィリピン人学習者(成人、初級〜中級)。日常会話・敬語に加え、介護・医療現場の実務日本語への実用ニーズを持つ層。
```

### English (standard)

```
Our primary target users are adult Japanese-language learners from the Philippines -- either partners (spouses or fiance(e)s) of Japanese people who want to learn Japanese for daily communication, or Filipino workers/residents in Japan who need Japanese for their jobs and daily life. We primarily target beginner-to-intermediate learners. Beyond general needs like everyday conversation and polite speech (keigo), we specifically target users with practical needs tied to real-life and workplace situations, such as Japanese used in caregiving and medical settings (covered by our premium scenes).
```

### English (short)

```
Adult Filipino learners (beginner-intermediate) who are partners of Japanese people, or who live/work in Japan and need Japanese for daily life and work -- including practical needs like caregiving/medical workplace Japanese.
```

---

## Part 2② アプリが提供する価値

### 日本語版(標準)

```
本アプリは、AIキャラクターとのシーン別会話練習(日常会話からビジネス・介護・医療現場の実務日本語まで全18シーン)を通じて、実践的な日本語運用能力を身につけられる価値を提供する。音声入力・音声読み上げの両方に対応しており、耳と口を使った実践的な練習が可能。会話中に出てきた難しい語はタップするだけで意味を確認できる辞書機能を備え、学習の妨げになる要因を減らしている。また、会話数・連続学習日数などの学習統計により、日々の学習の進捗を可視化できる。
```

### 日本語版(短縮)

```
AIキャラクターとのシーン別会話練習(全18シーン)で実践的な日本語運用能力を養える。音声入力・読み上げ対応、会話中の難語をタップで確認できる辞書機能、学習統計による進捗の可視化を備える。
```

### English (standard)

```
The app helps users build practical, real-world Japanese conversation skills through scenario-based practice with AI characters across 18 scenes, ranging from everyday conversation to business, caregiving, and medical/workplace Japanese. It supports both voice input and text-to-speech playback, enabling practice of both speaking and listening. An in-conversation dictionary lets users tap any unfamiliar word to see its meaning, reducing friction during practice. Learning statistics (conversation counts, streaks, etc.) let users visualize their day-to-day progress.
```

### English (short)

```
Scenario-based AI conversation practice across 18 scenes (everyday to business/caregiving/medical Japanese), with voice input/output, a tap-to-look-up dictionary, and progress statistics.
```

---

## Part 3① クローズドテストで学んだことに基づいて加えた変更

### 日本語版(標準)

```
クローズドテストで得たフィードバックを受け、以下の変更を行った。無料プランの1日あたり利用回数を5→10メッセージ(広告視聴で最大20)へ引き上げ、初回起動時のオンボーディングを拡充し、会話中の難語をタップして意味を調べられる辞書機能を追加した。

また、テスト期間中に開発側で発見した品質・コンプライアンス上の課題として、統計画面の表示不具合4件、通知履歴の削除に関する不具合、AIデータ利用に関する同意画面の新設と表示崩れ対策、オフライン時に画面が進まない不具合、Premium判定のクライアント/サーバー間の不整合、返金が成立した際にPremium権限が正しく剥奪されない不具合に対応した。

テスト期間中は3回のアップデート(Build 16: 2026年8月3日配信、Build 18: 2026年8月6日配信、Build 21: 2026年8月10日配信)を配信し、発見した問題を継続的に修正しながらリリースを重ねた。
```

### 日本語版(短縮)

```
テスターの指摘を受け、無料枠を10/日へ引き上げ、オンボーディングを拡充し、辞書機能を追加した。開発側でも統計画面・通知履歴・同意画面・オフライン起動・Premium判定・返金時の剥奪処理など複数の不具合を発見・修正した。テスト期間中にBuild 16/18/21の計3回アップデートを配信し継続的に改善した。
```

### English (standard)

```
Based on tester feedback, we made the following changes: raised the free tier's daily message limit from 5 to 10 (up to 20 with a rewarded ad), expanded the first-run onboarding flow, and added an in-conversation dictionary feature.

We also identified and fixed several quality and compliance issues during testing: four display bugs in the statistics screen, a bug in notification-history deletion, a new AI-data-usage consent screen (along with a layout-overflow fix), a bug where the app would hang on a blank screen when offline, a client/server mismatch in premium status detection, and a bug where a refunded subscription failed to correctly revoke premium access.

We shipped three updates during the testing period -- Build 16 (released August 3, 2026), Build 18 (released August 6, 2026), and Build 21 (released August 10, 2026) -- continuously fixing issues we discovered along the way.
```

### English (short)

```
We raised the free daily limit to 10, expanded onboarding, and added a dictionary feature based on tester feedback. We also fixed several issues we found ourselves (stats display, notification history, a new AI-data consent screen, an offline-launch hang, premium-status sync, and refund handling). We shipped 3 updates during testing (Build 16, 18, 21).
```

---

## Part 3② 製品版の準備が整ったと判断した根拠

### 日本語版(標準)

```
以下の観点から、製品版としての準備が整ったと判断している。

開発プロセス: pre-pushフックによるflutter analyze/flutter testの強制実行と、GitHub ActionsによるCI自動テストを組み込んでおり、品質を継続的に担保している。

安定性: Android Vitals(クラッシュとANR)において、2026年7月15日〜8月12日の期間に記録された問題は0件だった(データ最終更新2026年8月12日)。

決済基盤: RevenueCatによる課金基盤の設定が完了しており、Real-Time Developer Notifications(RTDN)の接続も完了している(2026年8月10日)。また、返金が成立した際にPremium権限を正しく剥奪する処理の修正を本番反映済みである(2026年8月12日)。

プライバシー・データセーフティ: App Store側の審査でAIへのデータ送信に関する開示不足を指摘された経緯を受け、アプリ内にAIデータ利用同意画面を新設した(Android版はBuild 18で配信済み)。Google Play側のデータセーフティ申告についても、実装内容との整合を確認済みである。

ポリシー遵守: Play Consoleの「ポリシーのステータス」を確認したところ、問題は検出されていない。
```

### 日本語版(短縮)

```
CI/pre-pushフックによる自動テストを開発プロセスに組み込み、Android Vitalsではクラッシュ・ANRの記録が期間中0件、決済基盤(RevenueCat・RTDN・返金処理)の整備を完了、プライバシー/データセーフティの整合確認、ポリシーステータスに問題なしを確認しており、製品版としての準備が整ったと判断している。
```

### English (standard)

```
We consider the app ready for production for the following reasons.

Development process: flutter analyze and flutter test are enforced via a pre-push hook, and CI (GitHub Actions) runs automated tests on every change, ensuring continuous quality checks.

Stability: In Android Vitals (Crashes & ANRs), zero issues were recorded during the period from July 15 to August 12, 2026 (data last updated 2026-08-12).

Payments: Our RevenueCat billing integration is fully configured, including Real-Time Developer Notifications (RTDN), connected since August 10, 2026. We also shipped a fix (August 12, 2026) that correctly revokes premium access when a subscription refund occurs.

Privacy/Data safety: In response to an App Store review note about disclosure of data sent to AI providers, we added an in-app AI-data-usage consent screen (shipped on Android in Build 18). We have also verified that our Google Play Data safety declaration is consistent with the app's actual implementation.

Policy compliance: We checked Play Console's Policy status and found no issues detected.
```

### English (short)

```
We're ready for production: CI and pre-push hooks enforce automated tests; Android Vitals recorded zero crash/ANR issues from Jul 15-Aug 12, 2026; our RevenueCat billing setup (including RTDN and refund-handling) is complete; our AI-data consent screen and Data safety declaration are in place and verified; and Play Console's Policy status shows no issues detected.
```
