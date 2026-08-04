# DECISIONS.md — 決定記録(追記専用・削除禁止)

形式: `日付 | 決定 | 理由`

- 2026-06 | 状態管理は素のsetStateのみ(Riverpod等未導入) | 規模に対して過剰、学習コスト回避
- 2026-06 | 音声・API baseは voikerchat.com 固定ハードコード | 意図的仕様(シークレットではない)
- 2026-06 | RevenueCat: CANCELLATIONではプレミアム降格しない。EXPIRATIONのみ降格 | 解約予約≠期限切れ。期間内は権利あり
- 2026-06 | 本番AIは claude-haiku-4-5 固定($0.0049/会話)。Gemini A/BはPhase 2aに延期 | コストと品質のバランス確定済み
- 2026-07 | BuildContext無しサービス層のi18nはB案=lookupAppLocalizations(Locale) | context注入は影響範囲が大きすぎる
- 2026-07-05 | CLAUDE.mdは不変の指針のみ。状態はSTATE.md、決定はDECISIONS.mdに分離 | 古い状態記載が不具合原因になるため(外部メモリ化)
- 2026-07-05 | Phase2の順序をAdMob先・push通知後に変更 | 収益直結を優先(事業設計図v1.1)
- 2026-07-05 | コミットは 262262561+shibuyer-jp@users.noreply.github.com を使用 | 他メールはVercelがデプロイをブロック(tokyo-bibleで実証)
- 2026-07-06 | 特商法ページの氏名は「屋号(Shibuyer)+個人名(安倍隆任)」併記固定、住所・電話番号は「請求があれば遅滞なく開示」で非公開 | 消費者庁ガイドラインで氏名は省略不可、住所等は請求時開示可
- 2026-07-08 | アカウント削除は `/api/delete-account`(全ユーザーテーブルを明示DELETE→`auth.admin.deleteUser`)、成功後にサインアウト+オンボーディングprefsクリア+匿名再サインイン | ストア(Apple/Google)必須要件。FK cascade有無に依存しない堅牢化。削除後もアプリが継続動作する状態を保つ
- 2026-07-08 | Flutterのローカルanalyze/test不可な作業環境ではmain直pushせずfeature branch+CI検証→mergeとする | redなmainを避ける。api単体のような検証容易な変更は従来どおり直pushも可
- 2026-07-17 | 広告視聴ボーナス付与(rate_limits.daily_limit+5)をクライアント直接Supabase書き込みから `api/ad-reward.ts`(service role)経由に変更し、クライアントによる rate_limits 直接UPDATEのRLSを禁止 | T-35(クラウドTTSのサーバー側検証)実装前提として、usage_logs.ad_rewardの偽装・rate_limits改ざんを防ぐため。AdMobのSSV(広告視聴自体の真正性検証)は未対応、BACKLOG-Phase2.md #11 へ
- 2026-07-25 | 通知機能(PR-1〜3)実装中の派生修正として StreakService を修正: (1) getCurrentStreak() はローカルキーが無い場合(初回起動/再インストール)のみSupabase復元を待つ、ローカルキーがあれば従来通り即返す (2) incrementStreak()の書き込みとSupabaseの裏同期(fire-and-forget)の順序非保証によるロスト更新(古いDB値がローカルの新しい値を上書きする)を防ぐため、user_streaks.last_updated と新設のローカルタイムスタンプキーを比較し、DB側が厳密に新しい場合のみ採用する方式(タイムスタンプ比較、案a)を採用 | 端末変更/再インストールでストリークが消える不具合と、fire-and-forget同期の競合による値の巻き戻りを解消するため。マルチデバイス同時書き込み(同一ユーザーが複数端末でほぼ同時にincrementStreak()を呼ぶ)によるロスト更新(最後にDBへ書き込んだ方が勝つ)は本対応では解消しない。発生頻度が低く、解消には別途キューイング等(案b)の設計が必要でコストに見合わないと判断し、明示的にスコープ外とした。将来この議論を再燃させる場合は、まず実際にマルチデバイス同時利用が問題化しているかの実測から始めること
- 2026-07-25 | purchases_flutter(v10.4.3)のiOS依存解決はSwift Package Manager(SPM)経由であり、ios/Podfile.lockにpurchases_flutter/PurchasesHybridCommon/RevenueCatのCocoaPodsエントリが存在しないのが正常な状態 | 以前「Podfile.lockがv8.11.0のまま=pod install未実施」と誤認していたが、実際にiOS実機ビルドを通した結果、pod installではなくSPM解決によってこれらのエントリはPodfile.lockから除外されることを確認(firebase_core/firebase_messaging/flutter_local_notifications/flutter_ttsは非SPM対応のためCocoaPods側に残る)。iOS下準備のTODOから「Podfile.lock更新」項目は削除し、この認識を正とする
- 2026-07-25 | リモートプッシュは今回のリリースでは引き続き「道2」(自動送信基盤は構築しない。既存のRemoteNotificationService受信側コードもこれ以上手を入れない)を維持する。PR #14(iOS APNsエンティトルメント追加: ios/Runner/DebugProfile.entitlements・Release.entitlements・project.pbxprojのCODE_SIGN_ENTITLEMENTS)はPhase2着手時まで**マージ保留**とする | entitlementsでaps-environmentを要求するようになった状態のまま`ios-release.yml`(手動署名、固定プロビジョニングプロファイル「voikerchat App Store 2026」使用)でアーカイブビルドすると、当該プロファイルがPush Notifications capability無しで作成されているため、entitlementsとプロファイルの不一致でxcodebuild archiveが失敗するリスクがある(自動署名なら不足capabilityを自動追加するが、手動署名ではされない)。今回のiOSリリース最終化を確実に壊さないため、Portal側のcapability有効化・プロファイル再作成とセットで行うPhase2まで保留する。Phase2着手時の手順はdocs/STATE.md「Push Phase2」を参照(2026-07-25版に更新済み)
- 2026-07-26 | notification_history テーブルは配信/スケジュール時点で解決済みの文字列(title/body)をそのまま保存し、表示時に現在の言語へ再ローカライズしない(「配信時点の言語で保持する」仕様として確定、PR #17) | メール受信箱と同じ考え方で、過去に届いた通知の文面を後から書き換えると「その時何が届いたか」という記録としての正確性が失われ、ユーザーの直感にも反する。表示時ローカライズ(翻訳キー+動的引数を保存し表示時に解決)への改修は、スキーマ変更・saveNotification呼び出し全箇所・履歴画面の表示ロジック変更・3言語での検証を要する中規模作業(半日〜1日)と見積もり、優先度低としてバックログへ(docs/STATE.md参照)
- 2026-07-26 | 広告(リワード広告)のNo Fill問題(TestFlight Build 8〜10で継続)は、AdMobコンソール確認の結果、原因がアプリがApp Storeで未公開であることに起因すると判断し、リリースブロッカーから除外する | コード側(初期化・リクエスト送信・SKAdNetworkItems)は正常に機能していることをBuild 9の診断ログで確認済み(onAdFailedToLoad: code=1 No Fill、サーバー応答自体は正常)。多くの広告ネットワーク/メディエーションパートナーは非公開(未審査/未リリース)アプリへの配信を制限するため、App Store公開後に再検証する方針とする。公開後タスクはdocs/STATE.md参照
- 2026-07-26 | rate_limits.daily_limit の日次リセット漏れバグを修正: api/chat.ts(checkAndIncrementRateLimit)と api/rate-limit.ts の両方にあった日次リセット処理(used_today のみリセットしdaily_limitを放置)に、daily_limit を基礎値(無料5/Premium50、isPremiumで分岐)へ戻す処理を追加した。広告視聴ボーナス(+5、上限10)は「当日限り」の仕様を維持し、翌日以降は自動的に基礎値へ戻る | 広告視聴ボーナスが恒久化してしまい、「毎日広告を見て回数を増やす」という収益設計が成立しなくなっていたため。api/rate-limit.tsにも同型のリセット処理が独立して存在し同じ不具合を抱えていたため、両方を修正対象とした。rate_limits.is_premiumカラムが既に存在し、両ファイルとも既にisPremiumをリセット処理のスコープ内で取得済みだったため、カラム分離(base_daily_limit/bonus_today)は不要と判断し、既存の単一カラム設計のままリセット処理を追加するに留めた
- 2026-07-26 | api/_constants.ts を新設し、FREE_DAILY_LIMIT/PREMIUM_DAILY_LIMIT/AD_BONUS/FREE_DAILY_CAP を一元管理する(api/chat.ts・api/revenuecat-webhook.ts・api/ad-reward.ts・api/rate-limit.tsが import)。クライアント側もlib/constants/rate_limit_constants.dartに同値をまとめ、lib/models/rate_limit.dart・lib/services/rate_limit_service.dartのフォールバック値をそこから参照するよう変更した | 従来はchat.tsとrevenuecat-webhook.tsに同じ定数が独立定義され「手動で同期させること」というコメントに依存していた(実際に同期漏れの温床だった)。ad-reward.tsも+5/10が生の数値リテラルだった。値の一元化により以後の同期漏れリスクを構造的に排除する
- 2026-07-26 | Fix 1(daily_limitリセット)にはTypeScript側の自動テストを追加しない(バックログ化)。api/*.ts向けのテスト基盤(jest/vitest/tsconfig/testスクリプト)がリポジトリに一切存在せず、かつ開発Mac(このリポジトリの主要ローカル検証環境)にNode.js自体が未インストールでローカル実行・検証ができないため | 新規にテスト基盤を用意すること自体が今回のバグ修正のスコープを大きく超える(依存追加・CI変更を伴う)ため、スコープ肥大を避ける方針を優先した。代わりにdocs/verification/daily_limit_reset_verification_20260726.mdで実機+SQLによる動作検証手順を用意した。テスト基盤整備はdocs/STATE.mdのバックログへ
- 2026-07-26 | ストア掲載文をv1.3→v1.4に更新し、「無料版とプレミアム」段落から無料枠の具体的回数(5回/日・広告視聴+5回)の記載を削除。動的な文言(「毎日会話を楽しめる」「広告視聴でさらに回数を追加」)に置き換えた | アプリ側は既にcallsRemainingToday等で残り回数を動的表示しており、ストア掲載文に固定数値を残すと、サーバー側のdaily_limit日次リセット処理の修正(別PR)などで将来値を変更した際にストア文言と実際のアプリ挙動が齟齬する。iOSはストア掲載文のみの変更でも新バージョン提出(新しい審査サイクル)が必要になるため、審査提出前の今のタイミングで直しておけば追加コストなしで反映できる。featureUnlimitedDesc(ARB、「無料の10倍」/"10x")は無料版の基礎値(5)自体を変更しないため対象外・変更なし
- 2026-07-26 | daily_limit日次リセットの実地検証(`docs/verification/release_verification_session_20260726.md`のPART B、旧`daily_limit_20260726_all_in_one.sql`のPART B)は**必須**であり、省略可能な任意項目ではないと明確化した(旧表記・報告で「可能なら」等の任意ニュアンスがあったため誤解防止のため再明記) | api/*.tsにTypeScript側の自動テストを追加しない判断(2026-07-26付、本ファイル参照)は「代わりに実地検証で動作を確認する」ことを前提にしている。この実地検証(PART B)を省略すると、daily_limitの日次リセットロジックが一度も検証されないままリリースされることになり、テスト省略の判断自体の前提が崩れる。シナリオB1(無料ユーザー)は必須、シナリオB2(Premiumユーザー)のみテスト用Premiumアカウントが無い場合に限り省略可
- 2026-07-26 | daily_limit PART B(会話送信)とPhase C(ストリーク検証)は異なるscene_idを使うことを統合検証セッション(`release_verification_session_20260726.md`)に明記した(Phase Cはscene_id=1固定、PART Bはscene_id=1以外) | 会話送信は`chat_screen.dart`が毎回無条件に`StreakService.incrementStreak(userId, sceneId)`を呼ぶ副作用を持つ。この関数は`rate_limits.last_reset_utc`は一切参照せず、端末の実時刻と`userId`+`sceneId`単位のローカルな「1日1回」ガードのみで動くため、PART Bのlast_reset_utc操作自体はストリーク判定に無関係だが、「メッセージ送信」という操作そのものがストリークの1日1回加算枠を消費する副作用を持つ。両者が同じscene_idを使うとPhase Cの期待値(streak=1→2→3)がずれる可能性があったため、scene分離で恒久的に無関係化した。なお`user_streaks`は`user_id`+`scene_id`の複合キーで管理されるシーン単位の独立した値(ユーザー単位のグローバル値ではない)であることをコード(`_restoreStreakFromSupabase`/`_syncStreakFromSupabaseIfNewer`が両方とも`scene_id`で絞り込んだ単一行を前提にしている点)から確認済みのため、scene分離により「取り合い」が「二重加算」に変わることはない
- 2026-07-26 | iOSビルド(Build 11)のArchiveが失敗した根本原因は「証明書の枚数上限到達」ではなく、`ios/Runner.xcodeproj`のRunnerターゲットRelease設定が`CODE_SIGN_STYLE=Automatic`+`CODE_SIGN_IDENTITY="Apple Development"`のままだったこと(構造的な設定ミス)と判定した。`ios-release.yml`を完全な手動署名(`-allowProvisioningUpdates`および認証系フラグを`Archive`/`Export IPA`ステップから削除)に、Release設定を`CODE_SIGN_STYLE=Manual`+`CODE_SIGN_IDENTITY="Apple Distribution"`+`PROVISIONING_PROFILE_SPECIFIER="voikerchat App Store 2026"`に修正した | Apple Developer Portal実査(2026-07-26)で判明した事実: (1)証明書一覧12枚中10枚が同一APIキー経由の自動作成品で、有効期限の分布(2027/07/11×3・07/12,16,17×4・07/25×1・07/26×2)がビルド履歴と完全一致=**成功していたBuild 10ですら新規証明書を1枚作成していた**。(2)一覧に`Apple Distribution`型は1枚も無い(全てDevelopment)。一方でBuild 10の実ログ(`security find-identity`出力)では`IOS_DIST_CERT_P12`から実際に`"Apple Distribution: Takatoh Abe (S6XJP274T2)"`(fingerprint `A529C75A91E310A6A73529E5FA0E8AC7F4A7A216`)が正しくインポートされていたことを確認済み(このp12はローカルキーチェーンへの取り込みである以上、ポータル側で失効済みでも見かけ上は成功しうる)。旧`ios-release.yml`コメントに記載されていた証明書ID「6M2X4S28G7」は実ログで検証されたものではなく、過去のコメントをそのまま引用した未検証の記載だったため誤りと判明・訂正した。(3)`CODE_SIGN_STYLE=Automatic`によりXcodeの自動署名管理が`-allowProvisioningUpdates`経由で毎回Development証明書を要求/作成しようとし、手動でインポートした`Apple Distribution`証明書・手動でインストールしたプロビジョニングプロファイルを実質的に無視していた。これが証明書量産の直接原因であり、今回の失敗は「たまたま枠を使い切った」のではなく構造的必然。証明書の失効による空き枠確保だけでは次回以降も同じ理由で再発するため、恒久修正として signing style を Manual に固定した
- 2026-07-26 | PR #14(iOS APNsエンティトルメント追加)の保留理由を再評価: 当初の保留理由は「プロビジョニングプロファイルにPush Notifications capabilityが無く、entitlementsとの不一致でarchive失敗するリスク」だったが、Apple Developer Portal実査で「voikerchat App Store 2026」プロファイルには**既にPush Notifications capabilityが有効になっている**ことが判明した(Created By: API Key、手動作成ではない。なぜ有効化されたか経緯は不明・未調査)。これにより当初の技術的な保留理由(capability不一致リスク)は解消したと判断する。ただし「道2」(今回のリリースでは自動送信基盤を構築せずPhase2へ先送りする、2026-07-25決定)という上位のビジネス判断は本件と独立しており、この事実だけでは変わらない。**結論: 技術的な保留理由は解消したが、戦略的な理由でのマージ保留は継続を推奨**(実装は行わず提案のみ。マージするかどうかは別途判断が必要)
- 2026-07-26 | シーン選択カードのハートボタン(お気に入り機能)を削除した(`lib/widgets/scene_preview_card.dart`)。非表示化ではなく削除を選択 | 調査の結果、`isFavorite`/`onFavoriteToggle`が呼び出し元(`scene_selection_screen.dart`)から一度も渡されておらず、状態の永続化(SharedPreferences/Supabaseいずれも)も一切行われていない未完成機能(実装当初から行き止まり)と判明。無料/Premiumの区別なく表示されておりPremium限定機能でもない。非表示化(コード温存)ではなく削除を選んだ理由は、コードを残すと将来「消し忘れ」や「実は動いていると誤認して再利用される」温床になるため。お気に入り機能自体は今回実装しない(バックログへ、再検討条件は`docs/STATE.md`参照)。代替として「最近使ったシーン」機能を別PRで検討する

#### 2026-07-30 Android クローズドテスト 14日タイマー起算

- 起算日: 2026-07-30(確認時刻 19:31 JST / 10:31 UTC)
- Play Console ダッシュボードで「12人以上のテスターにクローズド
  テストにオプトインしてもらう」に取消し線を確認
- 達成経路: ココナラ「もっとPython＠アンドロイドテスター」から
  受領した45アカウント(既存16名と合わせてリスト61名)
- 完走見込み: 2026-08-13 以降(Google 側の判定ロジックは非公開のため前後しうる)

**オプトイン不通問題の原因特定**
- 原因: SNS(Messenger)内蔵ブラウザ。端末の Google アカウントと
  別のログイン状態を持つため、テスターリスト登録済みでも
  「App not available」となる
- 検証: 同一テスターに Messenger ではなく Email でリンクを送付
  → 正常に "Become a tester" に到達(2026-07-30 夜)。以降、
  実テスターも順次オプトイン
- Play Console 側の設定(トラック、リスト、国/地域、URL)は
  すべて正常だった
- 正しいオプトインURL:
  https://play.google.com/apps/testing/jp.shibuyer.voikerchat
  (2026-07-29 に「ストアURLが正」と記載したのは誤り。撤回)
- 対策: 配布はメール経由。SNS 経由なら「リンクをタップせず
  コピーして Chrome に貼る」を明示
- 教訓: 一斉送信の前に必ず1名で疎通確認する。今回は16名に
  送付後に発覚し、3回の訂正連絡を要した

**外部サービスの保証条件(重要)**
- リジェクト時は審査通過まで無償で継続テスト参加
- ただし依頼者側で「アプリのアップデート」と「統計情報の共有」を
  1回以上行っていない場合、再テストに別途3,000円
- → Build 16 のテスト期間中リリースは保証条件・申請要件の両面で必須

#### 2026-07-31 usage_logs の記録漏れを発見・一部修正(PR #33)

**発見の経緯**
クローズドテスト2日目、テスターの内訳(国・言語・OS)を分析しよう
としたところ、locale / platform が全件 NULL であることが判明。
CHECK 制約は NULL を通すため、エラーにならず静かに欠落していた。

**NULL のまま運用されていたカラム**
- locale / platform: 全9箇所で未送信。クライアントも送っていなかった
  → PR #33 で修正
- session_id: 全箇所で未使用。chat.ts の logUsage() はパラメータを
  受け付けるが呼び出し側が渡していない → 未対応
- model: tts.ts は OpenAI TTS を呼んでいるが未記録 → 未対応

**未使用イベント(CHECK 制約に定義があるが insert 箇所がゼロ)**
- session_start / upsell_shown / upsell_clicked / upsell_converted
- 影響: アップセル導線の効果測定ができない。Premium 転換率の
  分析基盤が無い状態 → 未対応

**PR #33 の設計判断**
- api/_validation.ts に sanitizeLocale / sanitizePlatform を集約。
  chat.ts のみに存在したホワイトリスト検証を7ファイルで共用
- 入力型を unknown にし、req.body 由来の値に型注釈を信じない
- locale のフォールバックは en に丸めず null。usage_logs は
  観測用データであり、ja/en/fil 以外の端末ロケールを en として
  記録すると言語分布の分析が歪むため(フィリピンにはビサヤ語圏の
  テスターが存在することを確認済み)
- notification_scheduler.dart の _resolveLocale() は変更せず。
  用途が異なる(表示用は en フォールバックが正しい)

**教訓**
スキーマにカラムがあることと、値が入っていることは別。本番投入前に
実データで NULL 率を確認すべきだった。

### 2026-07-31 daily_limit 是正SQLは実行不要と判断

- 本番 rate_limits を確認: is_premium=false かつ daily_limit!=5 は
  4件(used_today は 2〜5、last_reset_utc は 7/24〜7/29)
- 全件が24時間を大きく超過しており、4b20102 以降の実装では
  次回API呼び出しで daily_limit も baseDailyLimit() へ戻る
- 4件とも現テスターではなく、2〜7日放置の開発用アカウント
- → migrations の一回限りSQLは実行しない。テスト期間中の
  本番DB操作を避ける判断
- 併せて判明: ad_reward 7件すべて metadata={}(通常経路)。
  AdMob が「要審査」で本番広告は no fill のため、これらは
  デバッグビルドのテスト広告(ca-app-pub-3940256099942544 系)と
  推定される
- no fill フォールバック経路(metadata.fallback=true)は
  本番で未発生。テスターが広告ボタンを押しているかの指標になる
- 2026-07-27 | **インシデント記録**: Android versionCode 7が2026-07-23 16:31にPlay Consoleクローズドテスト(Alphaトラック、日本・フィリピン)へ公開済みであったにもかかわらず、`shibuyer-ops/memory/handoff_20260723_4.md`記載の「クローズドテストは未開始・AABは一度もアップロードされていない」という同日時点では正しかった記録が、以降のhandoff/STATE.mdに訂正されないまま4日間連鎖して引き継がれ、2026-07-27時点まで「未配布」という誤った前提で作業計画が立てられていた。さらに、当該versionCode 7のビルドコマンド(`flutter build appbundle --release`のみ、`--dart-define`無し)には`SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY`が含まれておらず、`lib/main.dart`はこれらが空の場合`Supabase.initialize()`自体をスキップする設計のため、**現在配布中のビルドはチャット機能(中核機能)が動作しない不良ビルドである可能性が高い**(アプリ自体はクラッシュしない設計。チャット画面を開くとエラー表示になる)。発覚の経緯: `docs/ANDROID_RELEASE.md`作成のための調査で`lib/`配下の`fromEnvironment`呼び出しとビルド実績記録を突き合わせた結果、dart-define漏れを検出。その後ユーザーがPlay Console実画面を直接確認し、「未配布」の前提自体が誤りだったと判明した | **再発防止策**: (1) 今後Androidのリリースビルドは必ず`docs/ANDROID_RELEASE.md`の手順(dart-defineを明記したコマンド)を使用すること。手順書に無いアドホックなコマンドでのビルドを禁止する。(2) Play Console/App Store Connect等の外部サービスの配布状況は、記録(handoff/STATE.md)を鵜呑みにせず、疑わしい場合は実画面で確認してから作業計画を立てること(`docs/STATE.md`冒頭にも運用ルールとして追記済み)。(3) Build 13は`docs/ANDROID_RELEASE.md`の手順で既存Alphaトラックへ再アップロードし、不良ビルドを差し替える。14日タイマーは新AABアップロードでリセットされない仕様のため、トラック・テスターの再作成は不要
- 2026-07-27 | ストリーク(`user_streaks`/`streak_service.dart`)のリセット判定に案A(前回学習日が昨日なら+1継続、一昨日以前または記録無しなら1にリセット)を採用した | `resetStreak()`が定義済みだが呼び出し箇所ゼロ(デッドコード)で、何日サボってもストリークが減らず単調増加する不具合が判明。「N日連続」という表示・バッジ文言と実挙動の乖離を解消する必要があった。案A(前日継続/一昨日以前リセット)は最も標準的な「連続日数」の定義であり、Duolingo等の競合アプリの一般的な仕様とも一致する。判定は`user_id`+`scene_id`の組ごとに独立(`docs/DECISIONS.md` 2026-07-26のシーン単位方針を維持)。本番ユーザーがまだゼロの時点でのみ安全に変更可能だったため、Build 13で実施した。あわせて`_restoreStreakFromSupabase()`(端末変更/再インストール時の復元)にも同じギャップ判定を適用し、復元直後の初回表示から正確な値になるようにした(例: 42日間放置後の再インストールで「42」→次の会話送信で「1」に落ちるという体験上のバグを回避)。PR #13のタイムスタンプ比較方式(`_syncStreakFromSupabaseIfNewer`)自体は変更していない
- 2026-07-27 | ストリークの日付境界判定をUTC基準から端末ローカルタイム基準へ変更した(`DateTime.now().toUtc()`→`DateTime.now()`) | 主要ターゲットがフィリピン(UTC+8)在住の日本語学習者であり、UTC基準だと暦日の切り替わりがJST 09:00/フィリピン時間08:00に発生してしまい、朝型ユーザーで「同日に2回加算」「学習したのに前日扱いになる」不具合が起きうるため。ユーザーの体感(現地の暦日)と一致させる必要があった。複数端末間の新旧比較に使う`last_updated`(絶対時刻)は日付境界とは別概念のため、従来通りUTCのまま変更していない。移行時(既存のUTC基準日付文字列が端末に残っている場合)は、単純な文字列比較のため例外は発生せず、最大1日分のズレが生じる可能性があるのみ(許容範囲として設計)
- 2026-07-27 | プレミアム案内文(`featureAnimeDesc`)からシーン数の具体的な数字(「13」)を削除した(3言語) | 実際のシーン数は18(基本8+アニメ5+実用5、T-34で18に拡張済み)だが、`featureAnimeDesc`には旧仕様当時の「13」が更新されずに残っていた(既に実態と不一致の状態だった)。将来シーン数が変化するたびに文言修正が必要になる構造自体を避けるため、数字を含まない表現(「多彩なシーン」/"a wide variety of scenes"等)に置き換えた。一方`badgeBasicMasterDesc`/`badgeAnimeMasterDesc`(バッジ獲得条件の説明)は「あと何個必要か」という情報的価値があるため数字を残し、代わりにARBの`{count}`プレースホルダー化+`SceneService`の実件数を動的に埋め込む方式にして、数値と実装の齟齬が今後起きない構造にした
- 2026-07-27 | 通知の言語追従(アプリ内言語切替後、既存の予約済み通知が新しい言語で再スケジュールされる)は、Build 13着手前の調査で**既にPR #17(2026-07-25マージ)でmain反映済み**と判明し、Build 13では実装不要と判断した | Build 13着手時点の課題整理では「未対応」として計画されていたが、`main.dart`(`LocaleService.currentLocale.addListener`)と`notification_scheduler.dart`(`rescheduleForLocaleChange()`)を確認した結果、要件(pending通知取得・キャンセル・新localeで再登録・時刻/頻度不変・何度でも再生成・NotificationHistoryへの影響なし・リスナー重複無し)を全て満たす実装が既に存在していた。計画時点の課題認識が、別セッション(Mac)での並行作業の反映漏れにより古いままだったことが原因(`shibuyer-ops/memory/handoff_20260727_am.md`の教訓と同種)。なお、実機(TestFlight Build 12)で「通知履歴の3件が言語切替後も変わらない」という報告を受け再調査した結果、`notification_history_screen.dart`に`LocaleService`変更を検知して一覧を再読み込みする仕組みが無い(`_setupRealtimeListener()`がTODOのまま未実装)ことを発見。バックエンド側(予約通知の再スケジュール自体)は正しく動作するはずだが、画面が古いキャッシュを表示し続けていた可能性が高いと判断し、この画面にも`LocaleService.currentLocale`のリスナーを追加した(Build 13、同PR)
- 2026-07-27 | Paywall画面(`paywall_screen.dart`)で、RevenueCatが未configured(`_configured == false`、例: Androidの公開可能APIキー未注入)の場合に購読ボタンをdisabled化し、短い説明文を表示するようにした | RevenueCatダッシュボードにGoogle Playアプリが未登録のため、Android版には有効な`REVENUECAT_ANDROID_KEY`が存在しない。この状態で購読ボタンをタップすると、原因不明な汎用エラー「購入に失敗しました」が表示される(アプリ自体はクラッシュしない設計だが、テスターが不具合と誤認するリスクがある)。誤認したテスターがアンインストールすると、Google Playクローズドテストの14日タイマー要件(12名以上の継続オプトイン)に悪影響が出る可能性があるため、先回りしてUIレベルで無効化した。復元ボタンは対象外(未configured時も「有効な購入が見つかりませんでした」という非アラーミングな既存メッセージが出るため誤認リスクが低いと判断)
- 2026-07-27 | **【要注意・未検証の前提】** `notification_history_screen.dart`への`LocaleService`リスナー追加(上記「通知言語追従」PR #28の対応)は、Supabase上の`notification_history`テーブルにある`status='scheduled'`レコードが、ロケール変更時に`scheduleDailyReminders()`側で確実に削除・再作成される(=`cancelDailyReminders()`→`cancelScheduledByPayload('daily_reminder')`が古いscheduledレコードを消し、新しいレコードが新ロケールの文言で作られる)ことを前提としている | この前提はコード調査(静的読解)による推定であり、実機での動作確認はしていない。**もし実機確認(Build 13)で症状(通知履歴3件が言語切替後も変わらない)が解消しない場合は、まず`scheduleDailyReminders()`が既存のscheduledレコードを新ロケールで正しく作り直しているか(古いレコードがDB上に残存していないか)を最初に疑うこと**。画面側のリスナー追加(今回の修正)はあくまで「バックエンドのデータは正しいのに画面が古いキャッシュを表示し続ける」というUI層の問題を解消するものであり、バックエンド側のデータ更新自体に不具合があった場合はこの修正だけでは症状が解消しない
- 2026-07-28 | Paywall文言監査の結果、TestFlightで観測された「13 engaging scenes」表示は**コードの不具合ではなく、テスト対象ビルドがPR #28(Build 13、`1.0.0+13`)より古いビルドだったことによるもの**と判明した。`featureAnimeDesc`の「13」削除自体は既にPR #28でmainにマージ済み(3言語とも確認済み、`docs/DECISIONS.md` 2026-07-27「プレミアム案内文の数値除去」参照)で、追加のコード修正は不要 | 現在のブランチ`docs/verification-build12-scene-ui`名が示す通り、実機検証はBuild 12(`eaafe66`、PR #28マージ前)で行われていた。`git log`で確認した結果、`app_en.arb`/`app_ja.arb`/`app_fil.arb`のいずれもmain上では「13」を含まない文言(en: "A wide variety of engaging scenes to master Japanese" / ja: "日本語を習得できる多彩なシーン" / fil: "Iba't ibang kawili-wiling eksena para mahusayan ang Hapon")になっており、`featureAnimeTitle`("Anime Scenes"/"アニメシーン")との整合も取れている。**教訓**: 検証ブランチ名にBuild番号を明記する運用(`docs/verification-build12-scene-ui`)は良い実践だが、対応するmainのマージ状況(その検証がPR #28マージ前後どちらの状態を見ているか)もあわせて確認しないと、「mainで直したはずなのに直っていない」という誤認(実際は配布ラグ)が起きうる
- 2026-07-28 | Paywall 3言語横断監査で新たに発見した未翻訳を修正: `app_fil.arb`の`featureAnimeTitle`("Anime Scenes")と`featureStatsTitle`("Stats Dashboard")が英語のままコピーされていた(他の`feature*Title`キーは全てフィリピン語化済みだったため、翻訳漏れと判断)。それぞれ"Mga Eksenang Anime" / "Dashboard ng Estadistika"に変更した | PR #28の数値除去作業とは無関係の既存バグ(以前から存在)。3言語のARBキー完全一致(`en`/`ja`/`fil`のキー集合差分ゼロ)は確認済みで、他に同種の「値が英語のまま」という未翻訳はPaywall関連キーには見つからなかった。CLAUDE.mdの既存方針(fil訳はClaude機械下訳→本番化前にネイティブレビュー必須)により、この2件も他のfilキー同様ネイティブレビュー対象に含める(`docs/STATE.md`の「fil訳ネイティブレビュー」項目で追跡)
- 2026-07-28 | Build 14(`1.0.0+14`): App Store Guideline 3.1.2(自動更新サブスクリプションの「価格」と「更新期間」双方の開示義務)対応として、Paywall画面の価格表示に更新期間表記を追加した。ARBキー`pricePerMonth`(価格+期間が合成済みの固定文字列、フォールバック専用で使用箇所は`paywall_screen.dart`の1箇所のみと確認済み)を廃止し、`premiumPriceFallback`(価格のみ、"$12.99")と`premiumPriceWithPeriod({price})`(期間サフィックス、en: "{price}/month" / ja: "{price}／月" / fil: "{price}/buwan")の2キーに分割した。`paywall_screen.dart`は`RevenueCatService.getPremiumInfo()`の`storeProduct.priceString`(正常系)・`premiumPriceFallback`(異常系)いずれの価格文字列も`premiumPriceWithPeriod`に通してから表示するよう統一し、経路によらず必ず更新期間が付与されるようにした | 2026-07-28の前回監査で、`_dynamicPrice`(RevenueCat設定済み時に優先表示される`storeProduct.priceString`)が価格のみで期間表記を含まず、本番の正常系でGuideline 3.1.2の期間開示が欠落するリスクが判明していた(iOS TestFlight Build 12実機スクリーンショットで「$12.99」のみの表示を確認、裏付け済み)。サフィックス単純連結(`"$price/month"`のような文字列結合)ではなくプレースホルダ付きARBキーを採用した理由: 日本語は「{price}／月」、フィリピン語は「{price}/buwan」と語順・区切り文字がロケールごとに異なり、英語基準のサフィックスをそのまま結合すると不自然な表記になるため。`pricePerMonth`は他に参照箇所が無く、値の意味(価格+期間の合成)自体が新方式と非互換だったため、後方互換の別名維持はせず削除して置き換えた(未使用キーを残さない既存方針に従う)。フォールバック値(`premiumPriceFallback`)を「価格のみ」に変更したことで、`premiumPriceWithPeriod`との二重期間表記("$12.99/month/month"のような重複)は構造的に発生しない
- 2026-07-28 | `MaterialApp`(`lib/main.dart`)に`debugShowCheckedModeBanner: false`を恒久設定として追加した | iPad 13インチ用App Store掲載スクリーンショット撮影のため`flutter run`でシミュレータ起動を試みたところ、このMac(x86_64シミュレータ)は`--release`/`--profile`いずれも「Releasemode is not supported」「Profilemode is not supported」で非対応と判明し、`flutter run`はdebugモードでしか起動できないことを確認した。debugモードでは画面右上に赤い「DEBUG」リボンが常時表示され、コードを変更しない限り撮影する全画面に写り込んでしまうため、掲載用スクリーンショットとして使用できない状態だった。`debugShowCheckedModeBanner`はFlutterフレームワーク内部でassertion有効時(=debugビルド時)のみ描画される仕組みのため、リリースビルド(assertion無効)では本設定の有無にかかわらずそもそもバナーは表示されない。よってこの変更はリリースビルドの挙動に一切影響せず、pubspec.yamlのバージョンは`1.0.0+14`のまま据え置いた(進行中のiOSビルドRun ID `30318861694`の再実行は不要と判断)
- 2026-07-28 | Build 15(`1.0.0+15`): iPhone実機(TestFlight Build 14)で英語ロケールのみPaywall画面の「Terms of Service」「Privacy Policy」リンクが表示されない(日本語ロケールでは正常表示)という報告を受けて調査した結果、ARBキー欠落・横方向オーバーフロー・スクロール不可固定レイアウト・ロケール/RevenueCat状態による条件分岐のいずれにも該当する構造的な原因はコード上見つからず、iPhone 16 Pro(6.1インチ相当)・iPhone 16 Pro Max(6.9インチ相当)の両シミュレータでも英語ロケールで再現しなかった(実機固有の設定、特にDynamic Type/文字サイズ拡大設定が未検証の変数として残った)。原因を断定できないままではあるが、App Store Guideline 3.1.2の開示要件はスクロール位置に依存させるべきではないため、恒久対策として利用規約・プライバシーポリシーのRowを`SingleChildScrollView`内の`Column`末尾から`Scaffold.bottomNavigationBar`(`SafeArea`でラップ)に移動し、スクロール量やテキストサイズ設定に関わらず常時画面下部に固定表示されるようにした | 単純にテキストスケールをクランプする対策(案1)ではなく、Scaffold固定フッター化(案2)を採用した理由: 原因がDynamic Typeによる押し出しだと断定できておらず、「そもそもスクロール本文の一部である」という設計自体がGuideline 3.1.2の常時開示要件との相性が悪いため、原因の特定有無によらず構造的に解決できる案2を優先した。6.1インチ・6.9インチ両シミュレータ(英語ロケール)で修正後の表示を目視確認済み
- 2026-07-29 | App Store 1.0(`1.0.0+15`、commit `7c9687c`)を審査提出した(10:50 JST)。iOSアプリ本体・サブスクリプショングループ(ID `22225230`)・サブスクリプション商品(`voikerchat_premium_monthly`、Apple ID `6789889568`)の3点を**同一審査へ同時提出**。リリース方法は「承認後 自動リリース」を選択 | サブスクリプションの初回審査は3点すべてを提出物の下書きに揃えないと提出できない仕様(グループのみ・商品のみでは提出不可)。自動リリースを選んだのは、承認タイミングが不定(最大48時間)で手動リリース待ちの遅延を避けるため。掲載スクショはiPhone 6.9インチ(1320×2868)10枚+iPad 13インチ(2064×2752)7枚。6.5/6.3/6.1/5.5インチはAppleが自動縮小するため未登録でよい(★バージョンページの初期表示は6.5インチ枠なので、そのままドラッグすると寸法エラーになる。必ずメディアマネージャーで6.9インチ枠を展開すること)。スクショはASCの主要言語(日本語)ロケールに登録すれば他ロケールへ自動継承される。App Store Connectはフィリピン語ローカライズに非対応だが、フィリピンのApp Storeは英語表示のため英語版で足りる(Google Playはfil対応済みで、この差異に注意)
- 2026-07-29 | **インシデント記録**: サブスクリプション商品の価格が「アメリカ合衆国(USD)1件のみ」設定されている状態を提出直前に発見し、基準$12.99(USD)から175か国を自動計算して保存した(フィリピン ₱799.00、日本も自動生成) | 発見が遅れていた場合、日本・フィリピンのApp Storeで**購入不可**のままリリースされるところだった。App Store Connectのサブスクリプション作成フローは基準国の価格だけ設定した時点で見かけ上「完了」したように見え、他地域の価格生成を忘れる罠がある。**Google Play Consoleの定期購入商品作成でも同型の罠が存在するため、Android側の商品作成時も配信国すべてに価格が入っているか必ず確認すること**。なお価格変更はアプリの再審査不要で後からいつでも可能
- 2026-07-29 | アプリのプライバシー申告で「トラッキングに使用されるデータ」を**全項目「いいえ」**とした。申告した9データタイプはおおよその場所/オーディオデータ/その他のユーザコンテンツ/ユーザID/デバイスID/購入履歴/製品の操作/広告データ/クラッシュデータ | ATT(AppTrackingTransparency)が未実装のためIDFAを取得できず、AdMobは非パーソナライズ広告として動作する。実態と申告が整合している状態。**将来ATTを実装する場合はプライバシー申告の再提出が必要**になる
- 2026-07-29 | フィリピン価格 ₱799.00($12.99の自動換算)を提出時点では変更せず据え置く | 値下げは自由だが**値上げは既存購読者の同意が必要**なため、高めスタートが構造的に安全。またフィリピン国内の物価水準に対しては高めだが、主要ターゲットは日本在住フィリピン人(日本のApple IDを使用=日本価格が適用される)のため影響は限定的。現地在住者も本格的に狙う場合は ₱299〜₱499 を検討する。再検討は実購入データ取得後
- 2026-07-29 | RevenueCat Android有効化は**①Google Play Consoleで定期購入商品を作成 → ②RevenueCatにAndroidアプリ登録+Google Playサービスアカウント認証 → ③RevenueCat側でOffering/Productをマッピング → ④ビルドに`REVENUECAT_ANDROID_KEY`を渡す**、の順序を厳守する。**キーだけ先行投入することを禁止**する。期限はクローズドテスト期間内(〜2026-08-12目安) | 商品未作成の状態で`Purchases.configure()`が走ると、Offeringが空のままPaywallが破綻表示になる。現在のBuild 13はキー未注入により`RevenueCatService.isConfigured == false`となり購読ボタンがdisabled化される(2026-07-27の対応)ため、**安全に停止した状態**であって不具合ではない。この状態のほうが、中途半端に初期化されて破綻表示になるよりクローズドテスト中のテスターへの悪影響が小さい。マッピング時は**Entitlement識別子を`Premium`または`voikerchat_premium`に厳密一致(大小文字区別)させること**(`revenuecat_service.dart`の`checkPremiumStatus()`がこの2つのキーでのみ判定しているため、ズレると購入は成功するのにPremiumが有効にならないという最も気づきにくい不具合になる)
- 2026-07-29 | RevenueCatの`app_user_id`にSupabaseの`user_id`を渡す配線は**既に実装済みでコード修正不要**と確認した(`lib/main.dart:186-195`が匿名サインイン確立後に`revenueCatService.loginWithUserId(auth.currentUser!.id)`を呼び、`loginWithUserId()`内で`Purchases.logIn()`直後に`Purchases.restorePurchases()`も実行している)。Android有効化作業(上記)は**ダッシュボード設定のみ**で完結する | Android追加にあたり`app_user_id`未設定なら二重課金・復元不能のリスクがあるため事前確認した結果、問題なしと判明。**ただし構造上の制約を明示的に記録する**: 認証は匿名サインインのみ(`signInAnonymously()`、`main.dart:172`・`account_service.dart:81`。メール/SNSログインは未実装、App Review情報でも「サインイン不要」と申告済み)のため、`user_id`は「人」ではなく「インストール」単位になる。同一端末の再インストールは`restorePurchases()`がストアアカウント(Apple ID/Googleアカウント)から復元するため実害なしだが、**iOSで購入した人がAndroidで利用する場合の引き継ぎは原理的に不可**(匿名IDが別人扱いになり、かつAppleのレシートはGoogle Playで復元できない)。これはバグではなくログイン不要設計の帰結として受容する。解消にはメールログイン等の実アカウント導入が必要だが、初回起動時の離脱率上昇というトレードオフがあるため、リリース後に実際の問い合わせが発生してから着手を判断する(バックログ、`docs/STATE.md`参照)
- 2026-07-29 | Androidクローズドテストのテスター募集は妻経由のフィリピン人ネットワークで行い、**確保可能な上限が15名(欠番を除いた実数14名+開発者自身の`takatoh01@gmail.com`)**であることが判明した。Play Consoleのテスターリスト「Voikerchat Closed Test - PH」に確定11名を先行登録し、メールアドレス要確認の3名は回答後に追加する運用とした | Googleの要件は「**12名以上が14日間連続でオプトインし続けている**こと」。14名全員がオプトインしても余裕は2名分しかなく、**1〜2名の脱落で要件割れする綱渡りの状態**。前提として、テスターは登録した本人のGoogleアカウントでオプトインする必要があり、「メール追加=テスター成立」ではない(オプトインリンクを開いて`Become a tester`を押し、同じアカウントでインストールして初めてカウントされる)。オプトインURLは`https://play.google.com/apps/testing/jp.shibuyer.voikerchat`(Play Consoleの「リンクをコピー」はストア掲載URLを返すため、こちらを手打ちで使用。実機で表示を確認済み)。クローズドテストの国/地域はフィリピン・日本の2か国に設定しており、テスターのGoogle Playアカウント国がこの2か国以外だとアクセスできない点に注意(対象者は全員フィリピンからのアクセスであることを確認済み)
- 2026-07-29 | テスター向け募集文面から「14日間アンインストール禁止」という記載を削除し、代わりに「`Leave the program`を押さない」+「2週間の間、何日かに分けてアプリを開く」に置き換えた(英語版/タガログ語版とも) | Googleの仕様上、**一度オプトインすればアンインストールしてもカウントからは外れず**、外れるのは`Leave the program`(オプトアウト)を押した場合のみ。一方で製品版アクセス申請時には**テスターのエンゲージメント(実際にアプリを使ったか)が審査される**ため、実質的に重要なのはアンインストールの有無ではなく起動実績。誤った禁止事項を書くより、承認に実際に効く行動を書くほうが合理的と判断した。あわせて「Premiumの購入ボタンは意図的にOFF(タップしても何も起きない、報告不要)」という注意書きを文面に追加し、テスターが不具合と誤認して離脱するリスクを先回りして排除した
- 2026-07-29 | テスター謝礼の形を変更した。旧: J.(旧テスター取りまとめ役、2026-08-04匿名化)へ¥10,000をWise送金し、テスターには非開示。新: 同額を妻へ渡し、帰国時にテスター全員へお土産のチョコレートとして配布する | テスター取りまとめ役がJ.から妻へ変更になったため、謝礼の宛先も実態に合わせた。**J.への送金は一度も実行しておらず、本人へ伝達もしていないため、訂正や説明は不要**。現物のお土産にすることで送金手数料・為替リスクも不要になる。なおテスターへの謝礼自体はGoogle Playのポリシーに抵触しない。製品版アクセス申請ではテスターのエンゲージメント(実際にアプリを使ったか)が評価されるため、動機づけがあることはマイナスではなくプラスに働くと判断した。依頼内容は「14日間もたせばよい」ではなく「2週間のうち何日かに分けて、数分ずつ開く」と具体化して伝えること
- 2026-07-29 | **Google Play Billing Library 8.0.0 以降の必須化に係るポリシー違反は、2026-07-28 18:43 に Google 側で「違反が修正されました」と判定され解消済み**であることを確認した。よって引き継ぎ文書に「P6: Billing Library 更新期限 2026/8/31」として残っていた項目は**クローズする** | コード側の対応はPR #3(`purchases_flutter ^10.4.3`へのアップグレード、Billing Library 8 を同梱)で既に完了しており、2026-07-27 に Build 13(versionCode 13)を Alpha トラックへアップロードしたことで、Google の再スキャン(約一日後)により自動的に解消されたと推定される。**教訓**: Play Console のポリシー違反通知は引き継ぎ文書に一切記録されておらず、「違反が解消されました」という事後の通知で初めて存在を把握した(違反発生時の通知自体を見落としていた)。**今後はセッションごとに Play Console の「ポリシー→ポリシーのステータス」を実画面で確認すること**。製品版アクセス申請ではポリシー遵守状況も審査対象に含まれるため、未解消の警告を抚えていない状態での申請は避ける。なお targetSDK についても Play Console の App Bundle 詳細で Build 13 が「対象 SDK 36」と表示されていることを確認済みで、2026-08-31 期限の API 36 要件も充足している(`android/app/build.gradle.kts`は`targetSdk = flutter.targetSdkVersion`と暗黙指定だが、Flutter 3.44.4 で 36 に解決されることが実物で裏付けられた)
- 2026-07-29 | プライバシーポリシー(日英両版)の削除対象データ一覧に「通知履歴」を追記し、英語版の第12章見出しに欠落していた`id="data-deletion"`アンカーを付与、両版の更新日を 2026-07-29 に更新した | Play Console のデータセーフティで指定しているデータ削除用URL(`https://voikerchat.com/Privacy-Policy-v1.0#data-deletion`)の点検中に発見。**(1) 通知履歴の記載漏れ**: `api/delete-account.ts` の `USER_DATA_TABLES` には `notification_history` が含まれており**実装側は正しく削除していた**が、ポリシー本文の列挙にのみ反映されていなかった(ポリシーの最終更新 2026-07-24 の直後に通知履歴機能(PR #12)が入ったため)。記載より多く削除している状態だったのでユーザー不利益は無いが、Google の要件「削除/保持されるデータの種類を特定していること」と実態を一致させるため追記した。**(2) 英語版のアンカー欠落**: 日本語版には `id="data-deletion"` がある一方で英語版の同じ章には無く、英語版URLにアンカーを付けても該当章へ飛ばない状態だった。現在の登録URLは日本語版なので即時の影響は無いが、主要ターゲットがフィリピン人学習者であることを考えると将来英語版URLへ切り替える選択肢を残しておくべきと判断し、先に揃えた。**コスト根拠**: プライバシーポリシーはURLのみがストアに登録されており、ページ内容の更新に App Store / Google Play いずれの再審査も不要。審査中のiOS提出にも影響しないため即時対応した。**今後の運用**: データを永続化するテーブルを新設する際は、`api/delete-account.ts` の `USER_DATA_TABLES` とプライバシーポリシー日英両版の削除対象列挙を**同じPRで必ずセットで更新する**こと
- 2026-07-29 | **上記同日の「募集文面にPremium購入ボタンは意図的にOFFと記載する」という判断を撤回し、送付前に文面を差し替えた**。新文面はボタンの状態を説明せず、「Premiumはこのテストの対象外なので購入しないでほしい。ボタンが反応しない場合も想定内なので報告不要」という**行動の指定**にした | 旧文面は「購入ボタンはOFF」という**現在の状態**を説明していたため、クローズドテスト期間中にRevenueCat Androidを有効化すると文面と実態がズレ、テスターへのフォロー連絡が必要になる問題があった(そのためにP3の着手時期をテスト後に回すか検討していた)。行動指定に変えることで**有効化の前後どちらでも文面が正しいままになり、P3の着手時期の制約が消えた**。あわせて「絶対に課金されません」という表現を「購入しない限り課金されません」に修正した。**クローズドテストのテスターは自動的にライセンステスターにはならないため、実際に購入すれば本当に課金される**(iOSのTestFlightは常にサンドボックスだが、Google Playのクローズドテストは別仕様)。旧文面の表現はこの点で不正確だった。なお文面はこの時点で**未送付**であり、テスターへの訂正連絡は不要
- 2026-07-29 | **Google Play の定期購入商品を作成・有効化した(P3の①完了)**。アイテムID `voikerchat_premium_monthly`(iOSと同一)、基本プランID `monthly-autorenew`(1か月ごと・自動更新・有効・174か国/地域・下位互換性あり)。**RevenueCat の Product マッピングで使う文字列は `voikerchat_premium_monthly:monthly-autorenew`** | 設定値: 請求期間1か月 / 猚予期間7日(Google推奨値) / アカウント一時停止は自動計算(53日) / 再度定期購入許可 / 税金カテゴリ「デジタルアプリの販売」 / コンプライアンス「サービス」 / 年齢制限未選択(酒タバコ等の米国州法向け項目のため語学アプリは非該当) / 支払い地域制限なし。特典(購入フローでユーザーに表示): 50 conversation sessions per day / Access to all 13 scenes / Ad-free experience / Detailed learning statistics。**価格**: 基準 USD 12.99 から177か国を一括自動換算(確定は174か国/地域)。日本 JPY 2,120 / フィリピン PHP 895.00(VAT 12%含む)を目視確認済み。**フィリピンの ₱895 は iOS の ₱799 に現地VAT 12%を加えた税込表示(799×1.12≒895)であり、税抜の本体価格は両プラットフォームで一致している**(表示方法が異なるだけ)。App Store で踏んだ「基準国1か国だけ価格が入る」罠は、作成直後の価格表が全国「-」だったことで同型と確認され、ヘッダーのチェックボックスで全地域選択→一括設定することで回避した。**備考**: 基本プランは作成後に「有効化」を押さないと購入対象にならない(一覧の「有効な基本プラン」が 0→1 になることで確認)。アイテムID・基本プランIDはいずれも**作成後の変更・再利用が不可**。P5(フィリピン価格の妥当性)は現地表示が ₱895 になることを踏まえても判断変更なし(値下げは自由、値上げは購読者の同意が必要という非対称性がある以上高めスタートが正しい。実購入データ後に再検討)

### 2026-08-01 通知履歴の不具合を修正

**症状(2026-07-31 実機 iOS で発見、開発者による発見でありテスターからの報告ではない)**
- 通知を削除しても復活する
- 削除時に type 'Null' is not a subtype of type 'FutureOr<int>'
- 既読タブでしか削除できないように見える

**原因**
1. getHistory() が status で絞っておらず、status='scheduled'(received_at が未来)の行も画面に表示されていた。繰り返しリマインダーのため、削除しても次回起動時の再スケジュールで新しいIDの行が作られ「復活」に見えた
2. notification_history_service.dart の4関数が Future<int> を宣言しつつ .select() も .count() も付けておらず、戻り値が常に null で TypeError
3. 上記により _loadNotifications() に到達せず、Dismissible のローカル除去だけが残っていた
4. 「既読タブのみ」は錯覚。タブによる分岐は実装に存在せず、どのタブでも同じ症状だった

**判明した事実**
- 削除自体はサーバー側で成功していた(ID 49-51 の欠番で確認)
- TypeError は HTTP DELETE 完了後に発生していた
- is_read=true が scheduled 行に付いていたのは、画面に表示されていたためユーザーがタップできてしまったことによる

**既知の制約(今回スコープ外)**
- reconcileScheduledNotifications() はアプリ起動時にしか走らない。ユーザーが長期間アプリを開かなければ、予定時刻を過ぎても status='scheduled' のまま残る。実機での実害は未検証

**教訓**
テーブルの一部カラム(created_at)だけを見て「履歴が増殖している」と誤断定した。status / received_at を含む全カラムを確認していれば正しく判断できた。テーブルを語る前に全カラムを見ること。

### 2026-08-01 統計画面の不具合を修正(PR #35)

**発見の経緯**
Premium 限定機能のため一度も動作確認されていなかった。2026-08-01、本番DBで rate_limits.is_premium を一時的に true にして実機(iOS)で確認したところ、5件の問題が判明。確認後は元に戻した。

**確認された表示(実機)**
- シーン進捗のタイトルが「1」「2」と scene_id の生値
- お気に入りシーンも「2」と数字
- 学習時間が「0h」(セッション2件×5分=10分が時間単位で切り捨て)
- 連続日数が「0」(前日に会話記録があるにもかかわらず)
- 合計トークン696に対しシーン別合計523(差分173)

**原因と対処**
1・2: label_helpers.dart の sceneName() を呼んでいなかった → _displaySceneName() を追加して適用
3: Math.floor(分/60) で60分未満が必ず0。11セッションまで0hだった → 分の生値を返し、表示側で整形。算出式(セッション×5分)は維持
4: analytics.ts が usage_logs から UTC 日付境界で再実装しており、streak_service.dart のローカル日付境界と食い違っていた → StreakService.getOverallCurrentStreak() を新設し、user_streaks を既存の evaluateGap()/localDateString() で判定してから最大値を取る。analytics.ts の consecutiveLearningDays は削除
5-a: シーン1の「メッセージ1・トークン0」はオープニング台詞のみの正常な値。対応不要
5-b: トークン集計元の二系統(usage_logs vs conversation_sessions)は設計変更を伴うため保留。STATE.md に記録

**設計判断の記録**
単純な MAX(streak_days) は不適切と判明。resetStreak() が未使用のため、放置されたシーンの古い streak_days が DB上に残り続ける。「2週間放置した10日」が「今3日連続」を上回る恐れがあった。連続日数の算出をクライアント側で行う案(a)を採用。サーバー側で再実装する案(b)は、今回問題になった「同じロジックの重複によるズレ」を再生産するため却下。チャット画面の🔥バッジ(シーン単体)と統計画面(全シーン最大)で数字が異なる差異は既存のまま。「全体の連続日数」の定義を再設計する必要があり、今回スコープ外

**ドキュメントの誤りを発見(同日修正済み)**
- Database-Schema-v1.0.md の conversation_sessions.scene_id が UUID と記載されているが、実DBは text 型で "1"〜"18" の数値文字列(2026-08-01 確認)
- Supabase のプロジェクト表示名が voikerchat-prod。過去の記録にある "Japanese-learning-app" は古い(STATE.md訂正済み)

### 2026-08-01 リリースノートの記載精度について

Build 16 のリリースノート初版に3件の不正確な記載があり、CC の差分確認により発見・修正した。

- PR #31 を「正しくカウントされるよう修正」と記載したが、実態は「上限が存在しなかった機能への新規上限追加」
- PR #32 の「PREMIUM の i18n」を影響ありとして記載したが、ARB化しただけで3言語とも値は "PREMIUM" のまま。表示上の変化はゼロ
- PR #29・#30 が Build 13 未反映の可能性があるが、断定できないため記載しない判断とした

原因: リリースノート作成時、PR番号と要約だけを渡し、実際の差分を確認していなかった。

再発防止: リリースノートは PR の差分(gh pr diff)を確認してから作成する。「修正しました」と書く前に、変更前後で表示が実際に変わるかを確認する。

### 2026-08-03 Android Build 16 配布・iOS 2回目リジェクトと対応(PR #36)

**Android**
- Build 16 を審査送信、8月3日 10:27 JSTに「選択したテスターに公開されました」を確認
- usage_logs の platform/locale は Build 16 配信以前から記録されていたことが判明(android/ja=4件、android/en=2件、最終記録00:27 UTC。NULLは233件残存)。どのPRで実装されたかは未特定

**iOS 2回目リジェクト**(Submission ID: `94530390-d70e-4942-b6fc-9c709f735099`、審査対象Build 15、審査端末iPad Air 11-inch(M3)、審査日2026-08-03)
- Guideline 5.1.1(iv): マイク権限の事前ダイアログに Cancel があり、権限リクエストを回避できる点を指摘
- Guidelines 5.1.1(i)/5.1.2(i): 第三者AIへのデータ送信についてアプリ内での開示・同意が不足

**対応**
- Build 17(PR #36)で Cancel 削除・AIデータ同意画面(`AiDataConsentScreen`)を新設
- プライバシーポリシー修正(commit `04eb421` / `06a0271`)
  - 見出し3を音声読み上げ含む形に拡張、OpenAI送信を本文に明記
  - DPA/SCCに関する記載を追加
  - 冒頭ボックスと末尾注記の更新日を2026年8月3日に統一(冒頭ボックスの「更新日：」ラベルを見落として一時的に不一致が生じ、Vercelのキャッシュ・デプロイ問題と誤認して調査していたが、原因はファイル内の記載漏れだった)
- App Store Connect のプライバシーポリシーURL(英語)を`-en`付きに修正
- Resolution Center に修正内容を英文で返信(14:38 JST)
- アプリ本体・サブスクリプショングループ・サブスクリプション商品の3項目を再提出、全て「審査待ち」

**確認された運用知見**
- サブスクリプション2件はアプリ本体の再提出では連動しない。個別に「審査内容を更新」が必要(2026-08-01に続き08-03も再現)
- 提出詳細ページの「App Reviewに再提出」はアプリ本体が却下状態だと押せない。バージョンページ側の「審査内容を更新」から出す
- Vercelの`Etag`はファイル内容のMD5と一致する(配信内容の切り分けに利用可能な診断手法として記録)

**未解決・要注意**
- Vercelプロジェクトが2つ(voikerchat / voikerchat-x621)存在する件: `voikerchat.com`は`voikerchat-x621`にのみ割り当て済みだが、push の都度両方にデプロイが走る構成。完走後に整理すべき技術的負債(STATE.md参照)
- `AiDataConsentScreen`の`Column`が`SingleChildScrollView`でラップされておらず、オーバーフローリスクが未検証のまま残っている(STATE.md参照)

### 2026-08-04 docs/ 配下の内部ドキュメント公開問題への対応(内部専用52件を internal-docs/ へ移動)

**発見の経緯**
シーン数記載監査(2026-08-03〜04)の過程で、`vercel.json`の`outputDirectory: "docs"`により`docs/`配下が丸ごと`voikerchat.com`のサイトルートとして公開されていることが判明。`STATE.md`・`DECISIONS.md`を含む内部専用の設計・運用ドキュメントが実際に`https://voikerchat.com/STATE.md`等のURLでHTTP 200で閲覧可能な状態にあることを実機確認した。加えて、公開されていた`STATE.md`にテスター氏名3名分の個人情報が平文で含まれていることも判明(別途対応、下記参照)。

**対応**
- `docs/`配下59件を「公開必須(7件: `index.html`・`support.html`・`legal-notice.html`・`Privacy-Policy-v1.0*.html`・`Terms-of-Service-v1.0*.html`)」「内部専用(52件)」に分類し、内部専用52件をリポジトリルート直下の`internal-docs/`(`migrations/`・`tasks/`・`verification/`のディレクトリ構造は維持)へ移動した
- `vercel.json`は変更していない(`outputDirectory: "docs"`のまま)。`internal-docs/`はVercelのoutputDirectory外のため、Vercelはこのディレクトリをデプロイしない
- `CLAUDE.md`・`api/*.ts`のコメント・`lib/*.dart`のコメント・`.github/workflows/ios-release.yml`のコメント、および移動先内部ドキュメント同士の相互参照(`docs/STATE.md`等)を`internal-docs/`基準のパスに一括修正した
- 本ファイル(`DECISIONS.md`)自体は追記専用のため、過去のエントリ内にある`docs/STATE.md`等の記載は**意図的に修正していない**(当時の記述として妥当)。今後このファイル内で他ドキュメントを参照する場合は`internal-docs/`基準で記述すること
- `HANDOFF_*.md`・`THREAD-HANDOFF_*.md`系(2026-06-23〜24の過去スレッド引き継ぎ記録)も同様の理由で内部の`docs/`表記を変更していない(当時の記録として妥当、シーン数記載修正時の前例踏襲)
- `DEPLOYMENT-GUIDE.md`のFolder Structure例が`docs/`配下に`Persona-Design-v1.0.md`等を含む古い構成のままだったため、`docs/`(公開)と`internal-docs/`(非公開)の現状構成に更新した。同ファイルの`outputDirectory: "docs"`等Vercelの仕組み自体を説明する箇所(コマンド例・トラブルシューティング)は変更していない(記載内容が現在も正しいため)

**個人情報の匿名化(付随対応)**
- `STATE.md`のテスター候補3名のフルネームをイニシャル表記に置換(下記詳細)
- `DECISIONS.md`の謝礼窓口担当者の氏名をイニシャル表記に置換(下記詳細)
- 開発者本人の私用メールアドレス(`takatoh01@gmail.com`)は変更していない(第三者PIIではないため対象外)

**未対応(記録のみ)**
- `voikerchat`/`voikerchat-x621`の2つのVercelプロジェクトへのデプロイ後、両方で旧`docs/`配下の内部ファイルパス(例: `/STATE.md`)が404になることの確認は、デプロイ環境がこのセッションから直接操作できないため人間側での確認が必要(STATE.md参照)

### 2026-08-04(続) RevenueCat Android有効化の実施、PR #37/#38のマージ、handoff運用の是正

**RevenueCat Android有効化(①②③完了、④のみテスト完走後に保留)**
[本人作業・2026-08-04、Google Cloud Console/Play Console/RevenueCatダッシュボードでの直接作業。Claude Codeによる未検証]
- Google Cloudプロジェクト`voikerchat`(Firebaseと同一)でPlay Android Developer API/Play Developer Reporting API/Cloud Pub/Sub APIを有効化
- サービスアカウント`revenuecat@voikerchat.iam.gserviceaccount.com`を作成(ロール: Pub/Sub編集者+モニタリング閲覧者)、JSONキーをDrive/Project_Credentials/API_Keys/に保管(秘密情報のため値はここに記載しない)
- Play Consoleにサービスアカウントを招待(アプリ情報閲覧/売上データ/注文と定期購入の管理)
- RevenueCatにPlay StoreアプリをApp ID `appf7acdb482b`で追加(Custom URL Scheme `rc-f7acdb482b`は自動生成・未使用)
- Product `voikerchat_premium_monthly:monthly-autorenew`のインポート成功(Published)、Entitlement `Premium`にAttach(App Store版と併存)、Offering `default`の`$rc_monthly`に追加
- 残: Real-Time Developer Notifications接続(2026-08-06以降、RevenueCat側の認証情報反映待ち。Play Consoleのトラック設定変更を伴わないためテスト期間中でも着手可)。④ビルドへの`REVENUECAT_ANDROID_KEY`投入は2026-07-29の決定どおりテスト完走後まで保留

**PR #37(シーン数18統一)・PR #38(docs公開URL是正)のマージ**
- PR #38を先にマージ(マージコミット`181b831`)。両PRとも`docs/`配下を編集する変更のため、ファイル移動を伴う#38を先に確定させ、後続の#37は移動後のパスに追従させる方針を取った(逆順だと#38側で同種のコンフリクトが発生していた可能性が高い)
- PR #37を最新`main`へ`git rebase`したところ、ファイル移動先へのパッチ適用はgitの自動リネーム検出で無コンフリクト解決された。ただしPR #37の本文が新規追記した`docs/tasks/T-34_premium-pro-scenes.md`等の文字列としてのパス参照(4箇所、リネーム検出の対象外)は手動修正が必要だった。CI全緑を確認後マージ(マージコミット`b787cc3`)

**運用知見(2026-08-04)**
- Play Consoleダッシュボードの「12人のテスターがN日間連続でオプトインしています」の12人は**仕様上の固定表示であり実数ではない**[ココナラ出品者回答、2026-08-04]。実際は毎日16〜19アカウントが稼働
- 統計情報が「データを使用できません」となるのは反映に約1週間かかるため[同回答]。配信開始2026-07-30起点なら8/6頃から表示され始める見込み
- テスター管理業者(ココナラ経由)は製品版申請の結果が出るまでテストを継続する契約[同回答]。テスター追加・補充は不要
- Google CloudのIAMロール検索は日本語表示名では引けない。`pubsub.editor`のようにロールIDで検索すること(「Pub/Sub Lite編集者」という紛らわしい類似ロールを誤選択しやすい)
- RevenueCatの「認証情報は36時間で反映」はReal-Time Developer Notifications接続にのみ適用。Productインポートは即日成功した
- Vercelのデプロイ反映後もブラウザキャッシュが残るため、確認は強制リロードまたはシークレットウィンドウで行うこと

**Play Console定期購入商品の存在再確認**
`voikerchat_premium_monthly`/`monthly-autorenew`/174か国/有効を再確認[本人報告・2026-08-04]。2026-07-29に作成・有効化済みだったが明示的なクローズ記録がなかったため、STATE.mdバックログの当該項目を正式にクローズした

**handoff運用の是正**
2026-08-03分のセッション記録`shibuyer-ops/memory/handoff_20260803.md`が、実際にはリポジトリへcommit&pushされておらず失われていたことが本セッション冒頭で判明(`shibuyer-ops`を`git pull`・検索しても不在を確認)。当日の作業内容自体は本ファイルの2026-08-03エントリ・STATE.mdには記録済みだったため実害はなかったが、再発防止のため`shibuyer-ops/memory/handoff_20260804.md`の「運用ルール」節に(1)handoffは必ずcommit&pushまで完了させる (2)セッション終了時に前回分が実際に保存されているか確認する (3)次スレ開始時はまずhandoffの実在を確認してから作業する、を明記した。あわせて「ドキュメント(.md)編集は必ずClaude Codeが行い、Takatoh本人には.md編集・git操作・gh CLI操作を依頼しない(Takatohに依頼してよいのはCCが実行できない作業=ブラウザ操作・目視確認・意思決定・外部連絡のみ)」というルールも追記した
