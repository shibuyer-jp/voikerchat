# iOS 却下(リジェクト)時の初動プレイブック

**作成日**: 2026-08-04
**目的**: App Store審査でリジェクト通知を受けた際、事実確認から対応方針決定・再提出までを迷わず進めるための手順書
**実行者**: Takatoh(App Store Connect実画面での確認・Resolution Center返信・再提出)
**CC(Claude Code)の役割**: コード修正が必要な場合の実装・PR作成・再ビルドのトリガー、`internal-docs/DECISIONS.md`への記録

---

## 0. 前提となる現在の状況

- Build 17(`1.0.0+17`)が **2026-08-04に In Review へ移行** `[確認済 2026-08-04、Takatohのメール確認]`。本書作成時点でまだ却下されていない。この情報は`internal-docs/STATE.md`(2026-08-03時点で「審査待ち」)にまだ反映されていない**[要反映]**
- 直近の却下(2回目、Submission ID `94530390-d70e-4942-b6fc-9c709f735099`)は Guideline 5.1.1(iv)・5.1.1(i)/5.1.2(i)で、2026-08-03 14:38 JSTに3項目(アプリ本体・サブスクリプショングループ・サブスクリプション商品)を修正の上再提出済み(`internal-docs/DECISIONS.md` 2026-08-03参照)。**現在のBuild 17 In Reviewはこの再提出の審査結果**
- 本書は「次に却下された場合」に備えた初動手順であり、現時点で新たな却下が発生しているわけではない

---

## 1. 却下通知を受けた際の初動(最初の30分)

1. **通知メールを読む**。Appleの却下通知メールには通常、該当するGuideline番号と簡潔な理由が記載される。`[要確認]` 正確なメール文面フォーマット(件名・本文の定型パターン)は過去の実績はあるが、テンプレ化した記録は残していない
2. **App Store Connectで該当バージョンのステータスを確認**。アプリ → バージョン一覧で「Rejected」等の表示になっているか確認する
3. **Resolution Centerを開き、審査担当者からの詳細メッセージを読む**(手順は下記1-1参照)
4. **Guideline番号を特定する**(手順は下記1-2参照)
5. **却下理由が「メタデータのみ」か「バイナリ(アプリの動作)」かを判定する**。Resolution Centerのメッセージ内に "metadata rejection" 等の明示的な文言があるか、または指摘内容が説明文・スクリーンショット・URL等ストア掲載情報のみに関するものかを見る(→ 2節Aへ)。アプリの動作・UI・権限リクエスト等に触れている場合はビルド修正が必要(→ 2節Bへ)
6. **却下理由がガイドラインの解釈自体に疑義がある場合は2節Cを参照**
7. **`internal-docs/DECISIONS.md`に事実を即座に記録開始**: Submission ID・審査対象Build・審査端末(記載があれば)・指摘Guideline番号・指摘内容の要約。対応方針や修正内容は決まり次第追記でよいが、**却下の事実そのものは対応着手前に記録する**(過去、通知の見落とし・記録漏れが再発防止事項として挙がっている経緯があるため、`internal-docs/DECISIONS.md` 2026-07-29のBilling Library教訓と同様の姿勢で扱う)

### 1-1. Resolution Centerの確認手順

`[要確認]` App Store Connectの正確なメニュー名・画面階層。過去2回の却下対応で実際にResolution Centerへ到達し英文で返信した実績はあるが(`internal-docs/DECISIONS.md` 2026-08-03「Resolution Centerに修正内容を英文で返信(14:38 JST)」)、具体的な画面遷移の手順そのものは記録されていない。判明している範囲:
- App Store Connect → 対象アプリ → 対象バージョンのページ内に、審査担当者からのメッセージ・返信欄が存在する
- 返信は英文で行う(過去2回とも英文、日本語での返信実績なし)
- **申請前にTakatohが実画面を確認し、この節を実際のメニュー名・URL・スクリーンショット付きで更新すること**(次回の却下発生時、または時間がある時に先んじて確認しておくことを推奨)

### 1-2. Guideline番号の特定と、その意味の調べ方

- 却下通知(メール・Resolution Center双方)に該当Guideline番号(例: `5.1.1(iv)`)が明記されるのが通常
- 公式ガイドライン全文: [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)で該当セクション番号を検索する
- **本アプリの過去の指摘は全てセクション5(Legal)配下**(下記3節参照)。まずセクション5、特に5.1(Privacy)を確認するのが早い
- Guideline番号だけでは具体的に何を直せばよいか分からないことが多いため、Resolution Centerの担当者メッセージ本文(番号より詳しい説明が書かれていることが多い)と併読すること

---

## 2. 却下パターン別の分岐

### A) メタデータのみの問題

**判定基準**: 指摘内容がApp Store掲載情報(説明文、スクリーンショット、キーワード、対応言語、URL、年齢設定等)に限られ、バイナリ(アプリ本体の動作)には触れていない場合。

**対応**:
1. 該当するメタデータをApp Store Connect上で直接修正する
2. Resolution Centerで修正内容を英文で返信する(テンプレは4節A参照)
3. **新ビルドは不要**。プライバシーポリシー本文の修正はURLのみがストアに登録されているため再審査不要という前例あり(`internal-docs/DECISIONS.md` 2026-08-03「プライバシーポリシーはURLのみ登録。ページ内容の更新にApp Store/Google Playいずれの再審査も不要」)。App Description等の他のメタデータも同様に、テキスト変更のみであれば新ビルドは不要と考えられる

**`[要確認]`**: 「審査列に戻らない場合がある」という点について、メタデータ修正のみの場合に審査キューでの待ち時間が短縮される、または順番がリセットされない可能性があるとApple全体の一般的な運用として言われることがあるが、**本アプリでの実績としては確認できていない**。次回発生時に実際の待ち時間を記録すること。

### B) ビルドの修正が必要

**判定基準**: 指摘内容がアプリの動作・UI・ネイティブコードの変更を要する場合(例: 権限ダイアログの文言・ボタン構成、画面の追加、機能の削除)。過去2回目の却下(マイク権限ダイアログのCancel、AI同意画面の欠如)はこのパターン。

**対応手順**:
1. コードを修正し、通常のPRフロー(ブランチ作成→実装→`flutter analyze`/`flutter test`→PR→CI緑確認→マージ)で`main`に反映する
2. `pubspec.yaml`の`version:`を1つ上げる。**ビルド番号の再利用は不可**。iOS/Androidで同じビルド番号を共有しているため、Android側で既に消費した番号と衝突していないか必ず確認すること(`internal-docs/ANDROID_RELEASE.md`「よくある失敗」参照)。**本書作成時点(`main`が`1.0.0+17`)では、次に使える番号は+18**
3. GitHub Actions `ios-release.yml`を手動トリガー(`workflow_dispatch`)。`use_test_ads`は`false`固定(ストア提出ビルドでは絶対にtrueにしない)
4. **所要時間の目安: 約10〜13分**(依存解決〜App Store Connectへのアップロード完了までのCI実行時間。過去8回の成功実行実績、`gh run list --workflow=ios-release.yml`で確認可能)
5. **CI完了後、Apple側でビルドが審査提出可能になるまでの反映待ち時間は上記10〜13分に含まれない**。`[要確認]` この反映待ちの所要時間は過去実績として記録されていない
6. App Store Connectでビルドが選択可能になったら該当バージョンに紐付け、Resolution Centerで英文返信(テンプレは4節B参照)の上、再提出する
7. **サブスクリプション関連の項目(グループ・商品)はアプリ本体の再提出と連動しない。個別に「審査内容を更新」の操作が必要**(`internal-docs/DECISIONS.md` 2026-08-03「サブスクリプション2件はアプリ本体の再提出では連動しない…2026-08-01に続き08-03も再現」、2回連続で再現している既知の挙動)
8. 提出詳細ページの「App Reviewに再提出」ボタンは、アプリ本体が却下状態だと押せない。バージョンページ側の「審査内容を更新」から出すこと(同上、2026-08-03)

**署名について**: 完全手動署名(Apple Distribution証明書+固定プロビジョニングプロファイル"voikerchat App Store 2026")。証明書関連のトラブルシューティングは`internal-docs/DECISIONS.md` 2026-07-26参照。

### C) ガイドライン解釈の相違

**判定基準**: Appleの指摘が実装の実態と食い違っている、または複数の解釈が可能なガイドライン文言について見解の相違がある場合。

**反論する場合の書き方**:
- 事実(実際のコードの実装内容、既存の開示箇所、スクリーンショット)を淡々と提示する。感情的な表現は避ける
- Appleの指摘が具体的にどの懸念を指しているのかを理解した上で、その懸念に直接答える(論点をずらさない)
- 該当機能のスクリーンショットや、実装箇所(該当画面のパス等)への言及を含める
- テンプレは4節C参照

**`[要確認]`**: 本アプリで反論が採用された実績はまだない。過去2回の却下はいずれも指摘を受け入れて修正・再提出しており(反論の実例なし)、Appleの反論への反応(通る場合とそのまま維持される場合の分かれ目)についての実地知見はない。

**反論すべきか・素直に直すべきかの判断基準は5節参照。**

---

## 3. 過去の却下履歴と対応

| # | 提出Build | Submission ID | 指摘内容(要約) | Guideline | 種別 | 対応 | 出典 |
|---|---|---|---|---|---|---|---|
| 1回目 | `[要確認]` おそらくBuild 15以前 | `[要確認、記録なし]` | Terms of Use リンクがApp Descriptionに無い(メタデータ起因) | `[要確認、正確な番号不明]` | A(メタデータ) | `[要確認]` おそらくApp Description修正のみで対応 | **本人記憶ベースの情報のみ。`internal-docs/DECISIONS.md`・`internal-docs/STATE.md`のいずれにも記録が見つからない**(本書作成にあたり`git log`・grep両方で検索したが該当なし。下記「発見した記録漏れ」参照) |
| 2回目 | Build 15(`1.0.0+15`) | `94530390-d70e-4942-b6fc-9c709f735099` | マイク権限の事前ダイアログにCancelがあり権限リクエストを回避できる/第三者AIへのデータ送信の開示・同意不足 | 5.1.1(iv)、5.1.1(i)/5.1.2(i) | B(ビルド修正) | Build 17(PR #36)でCancel削除・AI同意画面新設、プライバシーポリシー修正、2026-08-03 14:38 JST再提出 | `internal-docs/DECISIONS.md` 2026-08-03 |

**現在の状況**(却下ではなく審査中): Build 17が2026-08-04にIn Reviewへ移行 `[確認済 2026-08-04、Takatohのメール確認]`。この提出が3回目の却下となるか承認されるかは本書作成時点で未確定。

### 発見した記録漏れ

1回目の却下(Terms of Use関連)について、`internal-docs/DECISIONS.md`・`internal-docs/STATE.md`のいずれにも記録が存在しないことが本書作成中に判明した。`internal-docs/DECISIONS.md`2026-07-29の記載「App Store 1.0(`1.0.0+15`)を審査提出した(10:50 JST)」は、文脈上この提出時点が実質的な初回提出として扱われている可能性があり、1回目の却下がこの提出より前の別バージョン(1.0.0+15未満)に対するものだったのか、あるいは7/29提出そのものに対する却下だったのかは**本書作成時点のリポジトリ記録だけでは特定できない**。次回時間がある時に、Takatohの記憶やメール記録をもとに`internal-docs/DECISIONS.md`へ正式に追記することを推奨する。

---

## 4. Resolution Center返信の英文テンプレ

いずれもドラフトであり、実際の指摘内容に合わせて修正してから送信すること。過去2回とも英文で返信した実績に基づく(`internal-docs/DECISIONS.md` 2026-08-03)。

### A) メタデータのみの問題への返信テンプレ

```
Hello,

Thank you for your review. We have updated the [App Description / screenshots / age rating / etc.]
to address the issue you identified regarding Guideline [X.X.X].

Specifically, we have [修正内容を具体的に記述、例: added a direct link to our Terms of Use in the
App Description].

No new binary submission was required for this fix, as the change was limited to store metadata.

Please let us know if any further information is needed.

Thank you,
[担当者名]
```

### B) ビルド修正が必要な問題への返信テンプレ

```
Hello,

Thank you for your detailed feedback. We have identified the issue and released a new build
(Build [XX], version [1.0.0+XX]) that addresses Guideline [X.X.X].

Specifically:
- [修正1の具体的な説明]
- [修正2の具体的な説明]

We have resubmitted the app, subscription group, and subscription product for review.

Please let us know if you have any questions.

Thank you,
[担当者名]
```

### C) ガイドライン解釈の相違に対する返信テンプレ

```
Hello,

Thank you for your review. We would like to provide additional context regarding the
Guideline [X.X.X] concern you raised.

[懸念点の要約(相手の指摘を正確に言い換える)]

In our implementation, [事実の説明。該当画面・コード上の挙動を具体的に]. Specifically,
[開示箇所やスクリーンショットへの言及].

We believe this addresses the concern of [Appleが懸念している本質]. However, if we have
misunderstood the requirement, we would appreciate further clarification so we can make
the appropriate adjustment.

Thank you for your time and consideration,
[担当者名]
```

---

## 5. 判断の分かれ目: 反論すべきか、素直に直すべきかの基準

以下は本アプリの実績(反論の実例なし)を踏まえた**判断の目安**であり、確立された社内ルールではない。`[要確認]` の位置づけで運用しながら精度を上げていくこと。

**素直に直すべきサイン**:
- 指摘が具体的で、実装のどの箇所を指しているか明確に分かる
- 過去に同種の指摘(5.1.1系のプライバシー・許可関連)を2回受けている。**本アプリはこの領域で解釈がAppleと食い違いやすい傾向がある**ため、3回目も基本的には指摘を受け入れる方向で検討する
- 修正コストが小さい(メタデータのみ、または1〜2画面の軽微な変更)
- 「ユーザーへの開示・同意」に関する指摘は、額面通り受け入れて開示を厚くする方が安全(App Storeの規約は保守的に運用されるため、グレーゾーンで反論して時間を浪費するより、開示過多の方向で倒す方がリスクが低い)

**反論を検討してよいサイン**:
- 指摘内容が実装の実態と明らかに食い違っている(例: 「機能Xが無い」という指摘に対し、実際にはX相当の機能が別の画面に存在する)
- 修正コストが非常に大きい(コア機能の削除・大幅な設計変更を要する)
- 同種の指摘が業界の他アプリでは一般的に許容されている挙動である(ただし本アプリでの立証実績なし、慎重に判断すること)

**共通の注意**: 反論する場合も、まず1節の手順で事実確認を尽くし、`internal-docs/DECISIONS.md`に指摘内容・自分たちの解釈・反論の根拠を記録してから送信すること。反論が通らなかった場合の次善手(結局修正して再提出)にすぐ移行できるよう、並行してBパターンの修正着手を検討することも有効。
