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
- 2026-07-29 | RevenueCatの`app_user_id`にSupabaseの`user_id`を渡す配線は**既に実装済みでコード修正不要**と確認した(`lib/main.dart:186-195`が匿名サインイン確立後に`revenueCatService.loginWithUserId(auth.currentUser!.id)`を呼び、`loginWithUserId()`内で`Purchases.logIn()`直後に`Purchases.restorePurchases()`も実行している)。Android有効化作業(上記)は**ダッシュボード設定のみ**で完結する | Android追加にあたり`app_user_id`未設定なら二重課金・復元不能のリスクがあるため事前確認した結果、問題なしと判明。**ただし構造上の制約を明示的に記録する**: 認証は匿名サインインのみ(`signInAnonymously()`、`main.dart:172`・`account_service.dart:81`。メール/SNSログインは未実装、App Review情報でも「サインイン不要」と申告済み)のため、`user_id`は「人」ではなく「インストール」単位になる。同一端末の再インストールは`restorePurchases()`がストアアカウント(Apple ID/Googleアカウント)から復元するため実害なし、と記載していたが、**[2026-08-07訂正・誤り]** この評価はクライアント層(RevenueCat)のみを見ており誤りだった。実際には**サーバー側`rate_limits.is_premium`は再インストール時の復元では一切更新されず、次回のRENEWALまで最大30日間無料枠のまま取り残される**(シーンロックは即座に解除される一方、日次上限・広告表示は無料枠のままという矛盾したUIになる。iOS 1.0.0+19実機検証で発覚、詳細は`internal-docs/reports/premium_state_mismatch_20260807.md`参照。`api/premium-sync.ts`新設で対応)。**iOSで購入した人がAndroidで利用する場合の引き継ぎは原理的に不可**(匿名IDが別人扱いになり、かつAppleのレシートはGoogle Playで復元できない)。これはバグではなくログイン不要設計の帰結として受容する。解消にはメールログイン等の実アカウント導入が必要だが、初回起動時の離脱率上昇というトレードオフがあるため、リリース後に実際の問い合わせが発生してから着手を判断する(バックログ、`docs/STATE.md`参照)
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

### 2026-08-04(続々) AI同意画面のオーバーフロー対策完了(PR #40)とBuild 16への未反映を確認

**調査の経緯**
実機(Xiaomi 23073RPBFG、Android 15)でアプリデータを消去して起動したところ、通知許可ダイアログは出るがAI同意画面(`AiDataConsentScreen`)が出ないと報告があり調査した。`lib/main.dart`の`RootScreen._resolveInitialScreen()`(main.dart:297-314)を確認した結果、判定ロジック自体(`SharedPreferences`の`kAiDataConsentAcceptedKey`のみで判定、Supabase側の永続化なし)には問題がなかった。Supabaseの`user_profiles`テーブル定義にも同意関連カラムは存在しないことを確認し、A(Supabase永続化による誤判定)は否定。呼び出し元(`lib/main.dart:311`)も正しく呼ばれておりB(デッドコード)も否定。

原因は**ビルドのタイミング**だった。`ai_data_consent_screen.dart`を新設したPR #36は2026-08-03 11:07 JSTにマージされたが、Android向けBuild 16のビルド元コミット(`0279eda`, `chore: bump version to 1.0.0+16`)は前日2026-08-02 08:59 JSTのもので、PR #36より前。`git show 0279eda:lib/screens/ai_data_consent_screen.dart`で該当ファイルがそのコミットに存在しないことを確認済み。一方iOS向けBuild 17(`0c790cf`, 2026-08-03 11:19 JST)はPR #36マージ後のコミットで、`git merge-base --is-ancestor`でPR #36マージコミットの子孫であることを確認済み。**つまりBuild 16(現在配信中のAndroid版)にはこの画面のコードが物理的に存在しない**。

**影響**
現在Androidクローズドテストで稼働中のテスターは、AIデータ利用への同意画面を一度も経由せずアプリを利用している状態にある。ストアのデータセーフティ申告(App Store Guideline 5.1.1(i)/5.1.2(i)対応で追加した開示内容)との整合は未確認。次回Android配信(Build 18)ではPR #36以降のコミットが反映されるため解消される見込み。

**対応(PR #40)**
`ai_data_consent_screen.dart`のオーバーフロー対策自体(本文を`SingleChildScrollView`に、同意/非同意ボタンを`Scaffold.bottomNavigationBar`へ分離、Paywall PR #30と同じ方針)を実施し、実機(Xiaomi 23073RPBFG、Android 15、フォントサイズ最大)で確認した。レイアウト崩れなし、「同意して続ける」→次画面遷移は正常動作を確認。「同意しない」ボタンの動作(同一Columnの兄弟要素のため関連性が高いと判断)とiPad Air 11-inch(iOS)での確認は未実施のまま残る(STATE.md「技術的負債」参照)。上記のBuild 16未反映問題は、この画面自体の実装不備ではなくビルド計画上の既知の制約として別途記録した

### 2026-08-05(続) 無料枠の実装と採算の実測

実測により、2026-08-05 前半の採算試算(推測ベース)を訂正する。

**実測値** [確認済 2026-08-05 / Supabase usage_logs 集計・直近30日]

| 経路 | 呼び出し数 | 平均入力tok | 平均出力tok | 1回あたり原価 |
|---|---|---|---|---|
| chat | 141 | 602.9 | 70.6 | $0.000956 |
| hint | 41 | 301.5 | 35.7 | $0.000480 |
| define | 9 | 299.3 | 73.1 | $0.000665 |
| vocab_summary | 2 | 523.0 | 185.5 | $0.001451 |
| recap | 0 | — | — | — |
| cloud_tts | 37 | null | null | 別課金体系・未測定 |

当初の推測値は実測の2〜4倍過大だった。
損益分岐課金率は5.46%(推測)→**1.86%(実測ベース)**に改善。
無料枠10への引き上げは採算上安全と判断する。

**利用状況** [確認済 2026-08-05 / 同上]
- user_days 46(ベータ開始7/30から約6日、テスター61名)
- chat 平均3.07回/日(上限5に対し6割、上限に届いていない)
- hint+define 平均1.09回/日(上限30の4%)
- recap+vocab 平均0.04回/日(上限10の0.4%)
- Premiumユーザー0人 → **[2026-08-07時点で陳腐化]** 開発者本人が実購入したため、この記録時点以降はPremiumユーザー1人(開発者自身)が存在する。詳細は本ファイル2026-08-07(続)参照

→ コストではなく**利用率の低さ**が主課題。テスター61名に対し1日平均8人弱しか起動していない。

**公開ブロッカーの格下げ**
- 実トークン計測 → **完了**
- プロンプトキャッシュ＋履歴制限 → 優先度「高」→「中」。一般公開でスケールした際に必要。ベータ〜初期公開では不要
- 補助機能のPremium無制限 → 優先度「高」→「中」。赤字転落ラインは1日497回で、通常利用では到達しない。ただし上限がない事実は変わらないため、保険として上限設定は残す

**新規の未確認事項**
- [未確認] cloud_tts(音声読み上げ)はAnthropicとは別の課金体系。トークン列がnullのため原価が測定できていない。上限の有無も未確認
- [未確認] hint/defineの日次上限30が実際に機能しているか。実測の最大値が6回で上限に誰も近づいておらず、検証できていない
- [未確認] recapが30日で0回。vocab_summaryと対で呼ばれる実装だがvocab_summary=2に対しrecap=0。早期リターンによる正常動作の可能性もある
- [解決済] chatの1日25回(上限超過)はTakatohのテスト用手動リセットによるもの。実装の問題ではない

- 2026-08-05 | 辞書機能の難語選定を、クライアント側の正規表現抽出(PR #48、ふりがな注釈「漢字(かんじ)」からの抽出方式、未マージのままクローズ)から、サーバー側AIによる文脈判断(PR #49、`api/define.ts`に`mode: 'sentence'`を追加しメッセージ全文を渡す方式、マージ済み)に変更した | 採用理由(PR #49本文の差分表より): (1)ふりがなOFF時でもボタンが常時表示され動作する(PR #48はふりがな注釈が無いと単語を拾えずボタンごと消えていた) (2)漢字を含まない返答でもAIがひらがな語を難語として選定できる(PR #48は正規表現の性質上ひらがなのみの語を拾えなかった)。トレードオフとしてAPI呼び出しが0回→1回/タップに増える(quota消費1)。※本来DECISIONS.mdへ記録すべき決定だったが、2026-08-05マージ時に本ファイルへの追記が漏れていたため事後追記する(2026-08-06)

### 2026-08-06 本番messagesログでの振り仮名精度検証、LLM生成方式を維持

`role='assistant'`の本番メッセージから「漢字(ひらがな)」パターンを正規表現で抽出し、頻度上位100件を目視確認した[本人報告、Claude Code未検証(本番Supabaseに直接アクセスできないため。使用SQLは`internal-docs/Token-Cost-Queries.md`と同様、Claude Codeが用意しユーザーがSQL Editorで実行)]。

**結果**: 明確な誤りは2件のみ。
- `素晴(すばら)らしい`(誤) — 正しくは`素晴(すば)らしい`。ルビが送り仮名側(「ら」)にはみ出している
- `訳(もうしわけ)ありません`(誤) — 正しくは`申(もう)し訳(わけ)ありません`。「申」の漢字自体が表記から欠落し、その読みが隣接する「訳」のルビに紛れ込んでいる

送り仮名を伴う語・熟語ともに、この2件を除き概ね正確だった。

**判断**: LLM生成方式(`api/chat.ts`の`FURIGANA_INSTRUCTION`、プロンプトでClaude Haiku自身に読みを付与させる方式)を維持する。決定論的な形態素解析方式への回帰は行わない。理由: 誤り率が実用上十分低く(上位100件中2件)、2026-08-05の決定(PR #49、辞書機能の難語選定を同じくAI文脈判断方式へ移行)とも整合する。上記2件のパターンに対応するルールを`FURIGANA_INSTRUCTION`へ追記して精度改善を図る(本ファイル参照、api/chat.ts変更のPR参照)。

### 2026-08-06 実トークン実測(n=157)による採算リスク解消と無料枠の確定

2026-08-05の実測(直近30日、chat 141件)に続き、全期間(n=157、chat)での実測値を確認した[本人報告、Claude Code未検証(同上)]。

**実測値**: avg_input 585 / avg_output 69トークン。input_tokens中央値625・p90 895・p99 1145・max 1187。月間利用は平均4.0メッセージ/ユーザー(p90 7.4)。

**判断**:
- 採算リスクは解消済みと判断する。2026-08-05の判断(損益分岐課金率1.86%)を追認
- プロンプトキャッシュ・履歴制限は一般公開ブロッカーから除外を維持(2026-08-05の格下げ判断を追認。p99/maxが低く頭打ちの兆候は履歴制限コードの存在ではなく実利用が短いことに起因すると2026-08-06セッションで別途確認済み)
- 無料枠は**10/日(広告視聴込み20/日)で確定**。`api/_constants.ts`の`FREE_DAILY_LIMIT = 10` / `FREE_DAILY_CAP = 20`は既にこの値で実装済みであることを確認した

- 2026-08-06 | 通知履歴の削除が常に失敗していた原因は、`notification_history`テーブルに`DELETE`のRLSポリシーが1件も存在しなかったことと判明した。`DELETE`ポリシーを追加して解消する(`internal-docs/migrations/2026-08-06_add_notification_history_delete_policy.sql`) | 実機(iOS)で削除操作が毎回失敗すると報告があり調査。`pg_policies`を確認したところ、RLS有効(`relrowsecurity=true`)かつポリシーはINSERT×2/SELECT×1/UPDATE×1の計4件のみで、DELETEに対応するポリシーが0件だった。**RLS有効時、あるコマンドに対応するポリシーが1件も無い場合はそのコマンドがデフォルトで全拒否される**。PostgRESTの`DELETE`はこの拒否をエラーとしては返さず「0行削除」として成功応答するため、`lib/screens/notification_history_screen.dart`の`deletedCount==0`判定が誤って「対象が既に削除済み」と解釈し、`Exception('Notification already deleted')`という誤った例外を表示していた(この判定自体はPR #34が2026-08-01に導入したコードで、そのときは実機での削除確認が行われていなかった)。あわせて、RLS修正後もこの判定自体が不適切(削除件数0でもユーザーの目的=「その通知を消す」は達成されている)と判断し、エラー表示せず正常終了として扱うよう修正した。**教訓**: Supabase側で直接作成したテーブル(`notification_history`はT-21当時にダッシュボードで直接作成されており、リポジトリにCREATE TABLE/RLS定義が残っていない)は、SELECT/INSERT/UPDATE/DELETEの4コマンドすべてについてポリシーの有無を確認すること。片方向(読み取り・更新)だけ確認して安心し、書き込み系の一部(今回はDELETE)が抜け落ちていることに気づきにくい。横展開チェックを`internal-docs/Rls-Policy-Coverage-Audit.md`に用意した

- 2026-08-06 | テスターフィードバック(`TESTER-FEEDBACK.md`Q2・Q5)で要望のあった「AI応答の日英併記」は、常時併記を採用しない。代わりに「タップで英訳を表示」方式(オンデマンド)を採用する | **常時併記を不採用にした理由**: 日本語の隣に常に英訳があると、学習者は日本語を読まずに英訳だけを見るようになり、推測して理解する過程が失われる。本アプリの目的は日本語学習そのものであり、その過程に価値がある。**一方で完全に日本語のみでは初級者にとって入り口が厳しく、離脱要因になりうる**ため、両者のバランスを取る設計として「必要なときにタップして調べる」オンデマンド方式を選んだ。これは既存の辞書ツール(難語Top3選定・なぞり選択→意味を調べる、いずれもT-31/PR #48〜49)と同じ「常時は出さず、必要な箇所だけ能動的に調べる」思想で一貫しており、UI設計上の整合性もある。**実装方式**: タップ時にAPIで英訳を取得する案A(オンデマンド)を採用し、応答生成と同時に英訳も生成する案B(事前生成)は不採用とした。案Bは出力トークンがほぼ倍増する(現状avg_output=69トークン、2026-08-05/06の実測ベース採算試算の前提が崩れる)のに対し、案Aは実際にユーザーがタップした分だけのコストで済む。**着手時期**: 未定。無料枠を5→10に引き上げたこと(commit `64ef08b`)でテスターの不満の主因(Q3「5問で上限」)が解消されている可能性があるため、次回以降のフィードバックで同じ要望が再度出るかを見てから着手を判断する。STATE.mdバックログに「AI応答の英訳表示(タップ方式)」として着手条件付きで追加した(着手条件: 次回フィードバックで同要望が再度出た場合)

### 2026-08-07 滞留オープンPRの整理と状態記録の同期

セッション開始時点でオープンPRが8件あり、うち6件が2026-07-26〜08-05作成のまま滞留していた。内容を1件ずつ照合し、以下の通り処理した。

| PR | 処理 | 判断理由 |
|---|---|---|
| #43 iOS却下時の初動プレイブック | マージ | main未反映。今回は承認されたが今後も使用可能な新規ファイルのみ |
| #45 機能別トークン集計SQL | マージ | main未反映。SQLは実行済みだがファイル自体が残っていなかった |
| #46 オンボーディング調査レポート | マージ | main未反映。「Step2未実装」「define/recap/vocab_summaryの導線が弱い」という発見は、2026-08-05の「コストではなく利用率の低さが主課題」という結論の根拠資料であり、リポジトリに残す必要がある |
| #42 製品版アクセス申請手順書 | 内容更新のうえマージ | `PRODUCTION_ACCESS.md`は完走後(2026-08-14前後)に使用する文書。ただし同PRが`TESTER-FEEDBACK.md`も新規作成しており、main側で2026-08-06に別途作成済み(commit `b93a18d`)のため add/add 競合。**main側の実記録を正とし、本PR側の「収集元一覧」「PR #34〜#40の分類」を統合**して解決した |
| #44 無料枠の単位・数値変更の決定記録 | **クローズ** | (1)DECISIONS.mdへの追記内容は、main側に`2026-08-05(続)`および`2026-08-06`としてより新しい実測ベースの記録が既にある (2)STATE.mdへの追記が「公開ブロッカー2件(実トークン計測/プロンプトキャッシュ+履歴制限)」であり、2026-08-06に完了・格下げ済み。**マージすると解消済みの古い情報が復活する** |
| #26 検証セッション文書のBuild 12対応 | **#60として作り直しマージ、#26はクローズ** | 旧パス`docs/verification/`を対象としており、PR #38(内部ドキュメントの`internal-docs/`移動)以降はそのままマージすると旧ディレクトリが復活し二重管理になる。STEP 6(F1〜F8)の内容のみ現行パスへ移植した。移植しなかったのは「現在の検証状況(2026-07-26時点)」サマリで、main側の2026-07-31追記(STEP1不要・STEP3実質完了・残りは完走後実施)と矛盾するため |

残るオープンPRは #14(iOS APNsエンティトルメント)・#5(Android署名fail-fast)の意図的保留2件のみ。

**PRODUCTION_ACCESS.md の更新**: チェックリスト項目1(Build 18配信)・5(API原価)・6(テスターフィードバック)を完了へ更新。項目9(`REVENUECAT_ANDROID_KEY`のBuild 18投入)は記録がなく[要確認]とし、Part 1②の「テスターは課金フローを一度も体験していない」という開示文の前提に関わるため「CCからの質問」へ追加した。Part 1③・Part 3①の回答案を、実際のテスターフィードバック内容で書き起こした。

**実画面確認による状態訂正** [確認済 2026-08-07 / Play Console実画面、スクリーンショット提示]

1. **Android Build 18は2026-08-06 13:46 JSTに配信済み**(versionCode 18、「選択したテスターに公開されました」)。STATE.mdは「配信中=Build 16」のままだった。これによりSTATE.md「技術的負債」に記載していた**「現在稼働中のAndroidテスターがAIデータ利用同意画面を経ずに利用している」という懸念は解消**。同意画面の実機動作はタブレットで確認済み[本人報告]
2. **Play Console「統計情報」は2026-08-07時点でも「データを使用できません」表示**。業者回答(反映に約1週間、7/30起点なら8/6頃から表示)より遅れている。未完了項目4(統計情報の共有、期限8/14)がブロックされている状態。8/9頃まで待って表示されなければ業者へ確認する
3. **iOS Build 17は2026-08-06に審査承認済みだが、手動リリース設定へ変更済みのため未公開**[本人報告]。公開タイミング(即時公開 / Android完走を待って同時公開)が未判断であり、未完了項目13として新設した。**公開までAdMob関連タスク一式が着手不可**である点が判断材料

**テスターフィードバックの位置づけ訂正** [本人報告 2026-08-07]: 2026-08-06に「Filipinoテスター1名分」として記録した内容は、配偶者より**フィリピン側テスター全体の総意**であるとの確認を得た。個人の意見ではなく複数テスターの合意された見解であるため、製品版アクセス申請Part 1③の材料としての重みが上がる。あわせてBuild 18配信後の再収集を2026-08-07夜に依頼予定[本人申告]。

- 2026-08-07 | Play Consoleからの通知を受け、Androidデベロッパーのパッケージ名登録(`jp.shibuyer.voikerchat`)をSTATE.md未完了項目15として追加した。期限は2026-09-30 | Googleは2026-09-30までにAndroidへ配信する全アプリのパッケージ名の登録を要求しており、未登録の場合はGoogle Playから削除される。既存Google Playアプリは自動登録される可能性があるため、手動登録の前に「パッケージ名」タブの一覧を確認する必要がある(未確認)。次ステップの署名鍵登録は、既存パッケージ名扱いなら公開証明書フィンガープリントのリストから選択する想定だが、リストに鍵が表示されない場合はassetsに`adi-registration.properties`を置いたリリースAPKを秘密鍵で署名してアップロードする所有権証明が必要になる(未確認)。トラック設定の変更にはあたらないため、クローズドテスト期間中(完走見込み2026-08-14)に実施しても14日タイマーには影響しない。出典: https://support.google.com/googleplay/android-developer/answer/16761053 、 https://support.google.com/googleplay/android-developer/answer/16984799

### 2026-08-07(続) RevenueCat Android実購入検証・iOS公開方針・優先度見直し

**未完了項目14の完了確認**
`REVENUECAT_ANDROID_KEY`はBuild 18に投入済みであることが判明した[本人報告 2026-08-07]。当初の方針(2026-07-29決定、「④ビルドへのキー投入はテスト完走後8/14頃まで意図的に保留、キーだけ先行投入は禁止」)から前倒しで実施されたことになるが、**いつ・誰が投入したかの経緯は記録が無く未特定**(要追跡)。開発者本人が実際にPremium定期購入を購入し、購入→entitlement反映→シーン解放までの課金フロー全体を検証したところ正常に動作した。この検証の過程で発見されたのが未完了項目9(プレミアムシーンのロック解除バグ)であり、PR #53で既に修正・マージ済みだったことも確認できた。

**PRODUCTION_ACCESS.mdの訂正**
チェックリスト項目9を✅完了へ更新。Part 1②の「クローズドテスト期間中は`REVENUECAT_ANDROID_KEY`を意図的に注入しておらず、テスターは課金・購読フローを一度も体験していない」という開示文は、上記の事実(キーは投入済み)と矛盾するため訂正した。ただし訂正後も**テスター自身が実際に購入した実績があるかは別問題であり[未確認]のまま**(開発者本人の購入1件が判明しただけで、テスターの購入実績は別途確認が必要)。「CCからの質問」から本件を削除した。

**新規リスク: 開発者本人の購入がライセンステスト扱いか未確認**
上記の実購入検証により、開発者本人のGoogleアカウントに対して実際に決済が発生している可能性がある。Play Consoleのライセンステストアカウントとして登録されていれば無償扱いになるが、未登録であれば解約しない限り毎月$12.99が実課金される。この点は今回の調査では確認できなかったため、STATE.md未完了項目16として新設し、速やかな確認を人間に依頼する。あわせて、2026-08-05(続)の実測記録「Premiumユーザー0人」は、この開発者本人の購入により陳腐化した(該当行に注記を追加済み)。

**iOSの公開タイミング判断(未完了項目13)の決定**
「Androidの完走を待って同時公開する」方針とすることを決定した。ただし、Androidクローズドテスト完走(見込み2026-08-14前後)は製品版アクセス申請の**提出条件**にすぎず、申請後の審査期間(通常7日以内、`internal-docs/PRODUCTION_ACCESS.md`5節)を経て初めて一般公開となるため、Androidの一般公開自体は**2026-08-21〜25頃**になる見込みである。したがって「2026-08-14に同時公開する」という前提は成立しない。「iOSだけ8/14頃に先行公開する」か「Androidの製品版承認(8/21〜25頃)まで待つ」かは、この記録時点では未確定のまま残す。判断は人間が行う。

**優先度の見直し: iOS Sandbox課金検証(未完了項目12)を公開前必須へ格上げ**
未完了項目14で検証できたのはAndroid(Google Play Billing経由)の課金フローのみであり、iOSはStoreKit経由の別コードパスを通る。PR #53で修正した「`ITEM_ALREADY_OWNED`のentitlement再確認→`ChatScreen.onPremiumUnlocked`→`SceneSelectionScreen.onPremiumUnlocked`という状態伝播」の不具合が、iOS側の購入完了イベントの扱いでも同様に再現しない保証はどこにもない。Android側で問題なく検証できたことをもってiOS側も安全とみなすのは早計と判断し、iOS Sandboxでの実機課金検証をiOS公開前の必須項目に格上げした。

- 2026-08-07 | バックログ「fil訳ネイティブレビュー」を「本番化前必須」から「公開後の改善候補」(優先度: 低)へ格下げした。妻への依頼はアクションアイテムから一旦外す | Takatohの判断により、優先度がそこまで高くないと評価されたため[本人判断 2026-08-07]。対象は既存21キー(notification_scheduler)に加え言語切替UI(PR #8)・通知トグル(PR #11)の新規キー。いずれも機械翻訳のまま公開されること自体は許容し、公開後にユーザーからの指摘や余裕が出た段階で着手を判断する運用へ変更する。STATE.mdの該当箇所(機能ステータス表・バックログ)を「改善候補(テスト期間中〜リリース後)」節へ統合した
- 2026-08-07 | Macの使用可否に関する記述を訂正した。「Macは使えない」ではなく「Macでは配布用IPA(App Store Connectへのアップロード)が作れない」が正確 | `ios-release.yml`のコメント(iOS 26 SDK要件をローカルのIntel Mac/Xcode 16が満たせずApp Store Connectへのアップロードが不可能、という記述)が、配布用IPA作成という限定された文脈の説明であるにもかかわらず「Macは開発に使えない」という誤った単純化で伝わるリスクがあると判明したため訂正した。実際にはシミュレータは問題なく使用可能で、App Store提出用スクリーンショットの撮影・iPad Air 11-inch等の各画面サイズでのレイアウト確認に実際に使用した実績がある[本人報告 2026-08-07]。過去の実例としてBuild 15(2026-07-28、DECISIONS.md該当日参照)でiPhone 16 Pro/iPhone 16 Pro Maxシミュレータを使ったPaywall表示確認を実施済み。STATE.md/CLAUDE.mdを確認したが「Macは使えない」という趣旨の記述はどちらにも見当たらず、実際の制約は`ios-release.yml`のコメントにのみ存在していた。誤解の再発を防ぐため、正確な記述をSTATE.mdの「技術的負債」節に新設した

### 2026-08-07 収益戦略の方針: 個人課金(B2C)は通過点、本命はB2B

**決定**: Takatohの方針として明言された[本人明言 2026-08-07]: 個人ユーザー
からの課金(B2C)に大きな利益は期待していない。B2Cは実績とユーザー数を
作るための通過点であり、本来目指すのは機関・窓口といったビジネス顧客
(B2B)からの収益である。

**この方針から導かれる判断基準**:
- B2C価格で数%の収益を取りにいくより、導入障壁を下げてユーザー数を
  増やすことを優先する(B2B交渉で示せる実績になるため)
- 機能開発の優先順位も、個人課金への転換率より継続率・利用者数を重視する
  方向で検討する

**関連する機会**: 育成就労制度(2027年開始見込み、雇用主に日本語教育の
実施が義務付けられる新制度)を狙ったB2B展開は、この方針の延長線上にある
具体的な機会として位置づけられる。受入企業・登録支援機関(市場・競合
メモに記載のKUROFUNE PASSPORTの顧客層と重なる)への展開を見据える。
詳細・時期は未調査のため継続ウォッチとする(`internal-docs/STATE.md`
「市場・競合メモ」参照)。

### 2026-08-07 Google Play価格をApp Store側(安い方)へ揃える

**背景**: iOS Sandbox課金検証(未完了項目12)で、App StoreとGoogle Play
の日本・フィリピン価格が食い違っていることが判明した。App Store:
¥2,000 / ₱799、Google Play: JPY 2,120 / PHP 895(いずれも税抜)。税込
換算ではフィリピンで約25%の差になる。

**決定**: 上記の収益戦略方針(個人課金からの収益最大化より、導入障壁を
下げてユーザー数を増やすことを優先)に基づき、**安い方(App Store側)へ
揃える**。Google Playの税抜価格を日本¥1,818/フィリピン₱713程度へ
引き下げる。

**[未確認]** App Store側の価格表示が税込か税抜かが未確定。この前提を
誤ると意図した水準に揃わないため、確定してから実施すること。
STATE.md未完了項目18として追加した。

**実施(2026-08-07)**: Play Console → 定期購入`voikerchat_premium_monthly`
→ 基本プラン`monthly-autorenew`の価格を、日本 JPY 2,120 → JPY 1,818
(税抜。VATなし表示のため税込も同額扱い)、フィリピン PHP 895 → PHP 713
(税抜、VAT 12%)へ変更した[確認済 2026-08-07、Play Console実画面]。
App Store側の価格(¥2,000/₱799)は価格一覧画面に税に関する注記が無い
ことから税込表示と判断し、Google Play側の税抜入力額が税込換算で
App Store側に揃うよう算出した。**[未確認のまま]** Appleが各国の税率を
織り込んだ価格ティアを提示する仕組みである点は一般的な理解に基づく
判断であり、公式ドキュメントでの確認は行っていない。STATE.md未完了
項目18を完了に更新した。

- 2026-08-07 | Google Play Console定期購入(`voikerchat_premium_monthly`)の特典テキストを「Access to all 13 scenes」から「Access to all 18 scenes」へ修正した(2026-07-29決定、`voikerchat_premium_monthly`作成時点の記載。本ファイル同日参照)。翻訳は英語(en-US)の0言語のみと確認したため他言語版の追加修正は不要だった | 2026-08-04のシーン数記載監査でコード実装(18シーン)とストア側記載の乖離を発見済みだったが、ストア側の修正自体はクローズドテスト完走後の予定としていた(トラック設定変更の運用ルールには該当しないため、実際には完走を待たずに実施可能と判明し前倒しで実施した)。アプリ内Paywall文言(`featureAnimeDesc`)は2026-07-27の決定で既に数字非依存化しているが、Google Play Console側の特典テキストは具体性が求められる欄のため数字を残す判断を維持した。この結果、Play Console側の特典テキストだけは今後もシーン数変更のたびに手動更新が必要な箇所として残る(STATE.md「技術的負債」参照)
- 2026-08-07 | 未完了項目15(Androidデベロッパーの確認・パッケージ名の登録)を完了とした。Play Console実画面で`jp.shibuyer.voikerchat`が登録済み・フィンガープリント確認済み(最終更新2026-07-13)であることを確認し、アカウント画面にも要件充足の表示があった[確認済 2026-08-07、Play Console実画面] | Googleによる既存Playアプリの自動登録が完了していたため、当初想定していた手動登録・署名鍵登録の作業は不要だった。ただしPlay以外で配信するアプリや今後新たにPlayへ出すアプリ(例: Beat Booth)は別途登録が必要になるため、完了はあくまで`jp.shibuyer.voikerchat`単体に限定される旨をSTATE.mdに明記した
- 2026-08-07 | `internal-docs/ROADMAP.md`を新設し、STATE.mdの未完了項目・バックログ・改善候補を時間軸(①日付/依存が明確なもの ②本番アクセス申請までにクリアすべきこと ③一般公開前に済ませたいこと ④公開後でよいこと)で再編した。STATE.md冒頭にROADMAP.mdへの参照リンクを追加した | STATE.mdはカテゴリ別・発生順の記録としては機能するが「いつまでに何をすべきか」が読み取りにくくなっていた。Android一般公開の現実的な日程が2026-08-14ではなく2026-08-21〜25頃であること(クローズドテスト完走→製品版アクセス申請→約7日審査が順次発生するため)、iOS 1.0.0+20は承認されてもAndroidと同時公開まで保留すること、年齢設定の不整合(4箇所)がiOS購入シートの「UNRATED」表示発覚により最優先事項に格上げされたこと、RevenueCat RTDN接続と返金時のPremium剥奪の調査がいずれもユーザー数増加に伴い拡大する収益漏れリスクであることを、時間軸整理の中で明示した
- 2026-08-07 | 未完了項目6(年齢設定の不整合)の4箇所を実際に確認した。利用規約(日/英)・プライバシーポリシー(日/英)は一貫して18歳以上、Google Playコンテンツレーティングは全年齢(IARC 3歳以上等)で、旧STATE.mdの注記「法務ページは13歳以上」は誤りだったため訂正した。App Store Connectのレーティングのみ未確認のまま残る | IARCの「ユーザー同士の交流」「制限のないインターネット」はいずれも本アプリには非該当のため、全年齢レーティングは誤申告ではなく法務文書側(18歳以上表記)がストアの実態と矛盾している可能性が高いと判断した。解消策として法務文書を13歳以上へ引き下げる改訂案をPR #80として作成した(未マージ)。Google Play側のレーティングを引き上げる代替案との比較・採否はTakatohの経営判断とし、PR本文に[要判断]として明記した
- 2026-08-07 | Google Play AI生成コンテンツポリシー(生成AIアプリのデベロッパープログラムポリシー)の遵守状況を調査した結果、必須要件(アプリ内でユーザーがアプリを離れずに不適切なコンテンツを報告できる機能)は既にPR #6(2026-07-24/25、`f34582c`)で実装済みであることを確認した。追加のコード対応は不要と判断し、STATE.md未完了項目19として「対応不要」の結論を記録した | 「本日まで誰も認識していなかった新規の遵守要件」という調査依頼の前提を検証した結果、事実と異なることが判明した。既存実装(`content_report_sheet.dart`)のコード冒頭コメントに当該ポリシーの要件文言そのものが実装意図として記載されており、過去のセッションで既に対応済みだった。詳細は`internal-docs/reports/ai_generated_content_policy_20260807.md`参照
- 2026-08-07 | 未完了項目6のApp Store Connect年齢制限指定を実画面で確認した結果、**13+**(172か国/地域。ベトナム12+・韓国12+・ブラジルA14)と判明。旧記載「App Store Connectは18+と記録されているが未確認」は誤りだったため訂正した。これにより4箇所の実態が確定: 法務文書=18歳以上(ここだけが浮いている)/ App Store Connect=13+ / Google Play(IARC)=全年齢 | App Store Connectが既に13+であるため、PR #80の法務文書13歳以上化案はApp Store Connectと一致し、Google Play側のレーティングを引き上げる代替案よりも変更対象が1箇所(法務文書のみ)で済み合理的と判断した。あわせてGoogle Playには IARC とは別に「ターゲットユーザーとコンテンツ」という対象年齢層の申告設定が存在し、13歳未満を対象年齢に含めるとFamilies Policy Requirements(子供向け広告SDKへの切替・保護者同意等)が新たに発生することを調査で確認した。法務文書を13歳以上へ揃える場合もこの申告では13歳未満を含めないことが必須と結論し、現状の申告内容の確認をSTATE.md未完了項目6のサブ項目として追加した(`internal-docs/reports/google_play_target_audience_20260807.md`参照)

### 2026-08-10 Build 21配信の決定と統計データ取得不能の記録

**決定**: 業者依頼「テスト中にアップデートを2〜3回」の3回目としてBuild 21を
配信する。Build 16(2026-08-03)・Build 18(2026-08-06)の2回で下限は既に
充足済みだが、**PR #69(Premium状態不整合の修正、`api/premium-sync.ts`)を
含む実害ある不具合修正をAndroidへ反映する必要があるため、どのみち一般公開前に
必要な作業を前倒しで実施する**。PR #53(プレミアムシーンロック解除)・PR #59
(オフライン起動白画面解消)・PR #58(通知履歴削除エラー修正)もBuild 18配信
(8/6 13:46 JST)より後にmainへ入っており、同様にBuild 21で初めてAndroidへ
反映される。versionCode 19/20は使わず**21**とした: 19はiOS 1.0.0+19
(TestFlight実機検証用)、20はiOS 1.0.0+20(App Store提出、本日Pending
Developer Releaseに到達)で既に消費済みのため(Play Consoleは18より大きければ
受理される)。`pubspec.yaml`を1.0.0+21へ更新しPR #84でマージ済み(実AAB
ビルド・Play Consoleアップロードは人間が`internal-docs/ANDROID_RELEASE.md`に
従って実施)。

**統計データ取得不能の記録**: Play Console統計3指標のうち2指標(1日の
アクティブなデバイス数・DAU)が引き続き取得不能である。インストール済み
ユーザー数は26(日本23/フィリピン3)まで生成されたが、統計データ表に
存在する行は2026-08-07の1日分のみで7/30〜8/6分は生成されていない。
アクティブデバイス数は期間指定(2026/8/1〜9)しても「データを使用できません」。
DAUはPlay Console上にGoogle公式の障害告知バナー(「現在、一部の1日の
アクティブユーザー(DAU)データをご利用いただけません。Googleは現在、
この問題の解決に取り組んでいます」)が表示されており、**これはアプリ側の
問題ではなく、Play Console側の生成遅延およびGoogle側の障害に起因する**
ものと判断できる。業者へは現状(3指標中1指標のみ送付可能)を報告した際、
クローズドテスト進捗画面(「12人のテスターが10日間連続でオプトインして
います」)を証跡として併せて提出した[実施済 2026-08-10]。詳細は
STATE.md未完了項目4参照。

### 2026-08-10(続) 法務文書の対象年齢を13歳以上へ改訂(PR #80承認)

**決定**: Takatohの内容レビューを経て、PR #80(法務文書の対象年齢を
18歳以上→13歳以上へ改訂する案)を承認し、mainへマージした。

**承認に至った判断**: App Store Connectの年齢制限指定が既に13+であり、
Google Playのコンテンツレーティングも全年齢(IARC 3歳以上等)である
ことから、4箇所中3箇所(App Store Connect・Google Play・改訂後の法務
文書)が13歳前後で揃う。法務文書側(18歳以上表記)だけが浮いていた
状態を解消する選択として、変更対象が1箇所(法務文書のみ)で済む本案が
最も合理的と判断した。

**不採用とした選択肢とその理由**:
- 課金を18歳以上に限定し年齢確認を実装する → 実装工数が過大なため不採用
- 18歳以上のまま据え置き、Google Play側のレーティングを引き上げる →
  13〜17歳の学生層をターゲットから失うため不採用

**保護者同意条項の性質(重要)**: 利用規約第5条に新設した「8. 未成年者
による購読」(英語版「Section 8. Subscriptions by minors」)は、**文言
のみの追加であり、チェックボックス等による同意取得の実装を伴わない**。
ユーザーが実際に保護者の同意を得たかどうかを技術的に検証・担保する
仕組みは無く、それを前提としてもいない。目的は同意の実効性を技術的に
確保することではなく、**未成年者が無断で購読した場合に事業者側が
「規約上は保護者同意を求めていた」と主張できる状態を作ることによる
リスク低減**にある。民法第5条に基づく契約取消のリスク自体(返金・
チャージバック)は本条項によっても完全には排除されない点は留意が必要。

**アプリ側の変更は不要**: `lib/`配下・ARBファイルのいずれにも年齢を
明示した文字列は存在しないことを確認済みのため、本改訂に伴うアプリの
コード変更・再ビルドは不要[確認済 2026-08-10]。

**マージ後の確認結果**: Vercel本番デプロイ成功後、以下4URLが実際に
13歳以上表記へ差し替わっていることを実画面で確認した[確認済 2026-08-10]。
- `Terms-of-Service-v1.0.html` / `-en.html`
- `Privacy-Policy-v1.0.html` / `-en.html`

STATE.md未完了項目6は完了にしない。検証条件「4箇所が一致していること」の
うち、Google Play「ターゲットユーザーとコンテンツ」の対象年齢層申告
(13歳未満を含めていないことの確認)が未確認のまま残るため、残作業を
この1点に絞ってSTATE.md/ROADMAP.mdへ記録した。

**あわせて発見した既存不備2件の扱い**: PR #80のレビュー過程で、本PRとは
無関係の以下2件を発見した。いずれも法務文書本体の追加改訂を要するか
判断がTakatoh確認事項のため、**今回は修正せず記録のみ**とした。
- プライバシーポリシーの節番号欠番(日英とも12が欠番、日本語版は
  英語版の「13. Language」に相当する節も存在せず日英で構成不一致)。
  STATE.md「改善候補」へ[優先: 低]として追加
- `internal-docs/ANDROID_RELEASE.md`のRevenueCatキー種別記載不足
  (2026-08-10の実作業でSecret API Key〈`sk_`始まり〉を誤って
  埋め込みかけるインシデントが発生、ビルド前に気づき未実行)。
  こちらはドキュメントの記載不足であり法務文書ではないため即修正した

### 2026-08-10(続2) Google Play対象年齢層を18歳以上のまま据え置く決定と、年齢設定4箇所の実態確定

**確定した4箇所の実態**:

| 箇所 | 状態 | 位置づけ |
|---|---|---|
| 利用規約・プライバシーポリシー(日英4ファイル) | 13歳以上 | PR #80で是正済み |
| App Store Connect | 13+ | 法務文書と一致 |
| Google Play(IARCコンテンツレーティング) | 全年齢(3+) | 評価軸が異なるため不整合ではない |
| Google Play「ターゲットユーザーとコンテンツ」 | 18歳以上 | 意図的に据え置き |

Play Console実画面(ポリシーとプログラム → アプリのコンテンツ → 
ターゲットユーザーとコンテンツ)で確認したところ、対象年齢層は18歳以上
(最終更新2026年7月14日)だった[確認済 2026-08-10]。当初懸念していた
「13歳未満が含まれている」状態ではなく、Families Policy Requirements
は発動していない。あわせて「管理」画面で、**「Googleが未成年と判断した
ユーザーによるアプリの使用を制限する(省略可)」にチェックが入っている**
ことが判明した。この設定により18歳未満の年齢層は選択不可の状態になって
おり、Googleは未成年と判断したユーザーに対して①Google Playでのアプリの
検索・ダウンロード ②アプリ内購入(定期購入の新規登録・既存の定期購入の
更新を含む)をブロックしている。

**決定**: Takatohの判断により、この設定は**現状(18歳以上・未成年制限
あり)のまま変更しない**。「変更を破棄」で画面を閉じ、Play Console側の
申告内容は一切変更していない。

**据え置きの決め手となった3点**:
1. 現在の「未成年ユーザーの使用を制限する」設定は、未成年による定期購入の
   新規登録・更新をGoogleが技術的にブロックしており、PR #80で追加した
   保護者同意条項(文言のみで同意取得の実装を伴わず実効性を担保しない)が
   カバーできていない部分を実質的に肩代わりしている。外すとこの保護が
   失われ、民法第5条に基づく契約取消(返金・チャージバック)リスクが
   顕在化する
2. 13〜17歳を対象年齢層に追加する場合、年齢確認画面の実装やAdMob側の
   広告設定調整を求められる可能性があるが、要件の詳細([未確認]、
   `internal-docs/ROADMAP.md`区分4「Google Play対象年齢層の13〜17歳への
   拡大検討」参照)は現時点で確定していない
3. 2026-08-14のクローズドテスト完走・その後の製品版アクセス申請を目前に
   控えた時期に、審査対象となりうる申告設定を動かすリスクを避けた

**事業方針との整合**: B2B・機関向けが本命でB2Cは通過点という既存の収益
戦略方針(2026-08-07決定)を踏まえると、Androidの13〜17歳枠を公開前に
取りに行く優先度は高くないと判断した。着手条件は一般公開後、学生層からの
実需要が確認できた段階とし、`internal-docs/ROADMAP.md`区分4(公開後で
よいこと)へ格下げして記録した。

**PR #80との関係**: 本決定によってPR #80(法務文書13歳以上化)が無意味に
なるわけではない。iOSはApp Store Connectの年齢制限指定が13+であるため、
実際に13〜17歳へ配信される。法務文書がこの実態に対して18歳以上のままだと
プラットフォームの配信実態より狭い契約年齢という矛盾が残るため、法務文書
の改訂自体は独立して必要だった。Android側の対象年齢層を18歳以上のまま
据え置く判断とは矛盾しない(Androidは法務文書が許容する範囲〈13歳以上〉
より狭く配信しているだけであり、規約が許容する範囲より狭く配信すること
自体はポリシー違反ではない)。

**クローズ**: 上記により、STATE.md未完了項目6(年齢設定の不整合を解消)を
完了とした。「4箇所が一致した」のではなく「4箇所の実態を確定し、残る
差分を意図的な仕様として許容することを決定した」形でのクローズであり、
検証条件の文言もこれに合わせて訂正した。製品版アクセス申請のブロッカーは
解消し、`internal-docs/PRODUCTION_ACCESS.md`のチェック項目4b(ターゲット
ユーザーとコンテンツの確認)も確認済みへ更新した。

### 2026-08-10(続3) ライセンステスト登録の確認完了とフィードバック再収集の見送り

**未完了項目16(開発者本人の購読の扱い)の確認結果**: Google Playからの
購入確認メール実物を確認した結果、`takatoh01@gmail.com`は既にライセンス
テストに登録済みであり、**実課金は一切発生していなかった**ことが判明した。
根拠は以下の4点: ①注文番号`GPA.3366-1618-4848-35600`(2026-08-06 15:58:47
JST) ②メール本文に「これはテスト用の定期購入で、このスケジュールに
従って繰り返されます。請求が行われることはありません。」と明記 ③アイテム名
「テスト: Voikerchat Premium (Voikerchat)」に「テスト:」接頭辞が付いている
④課金周期の表示が「¥2,120/5 分」で、実際の月額課金ではなくライセンス
テスト特有の短縮更新間隔(5分毎)になっている。**リスクは当初から存在
しなかった**ため、解約・返金申請・追加のライセンステスト登録はいずれも
不要と結論した。

**運用知見**: Play Consoleのライセンステスト登録一覧の画面を見るより、
**Google Playからの購入確認メールを確認するほうが確実**。テスト購入は
アプリ・Play Console双方の画面上の挙動が実購入と区別できないため
(購読状態・entitlementの見え方は同一)、メールに明記される「請求が
行われることはありません」の文言や「テスト:」接頭辞のほうが確実な
判別材料になる。

**未完了項目7の残作業(配偶者経由のBuild 18版フィードバック再収集)を
見送った判断**: Takatohは2026-08-10、再収集を実施せず既存分で対応する
ことを決定した。理由は回収の見込みが無いこと。製品版アクセス申請の
設問には、業者経由のテスターフィードバック4件(2026-08-10にTESTER-
FEEDBACK.mdへ2-2として記録済み、Android 14〜16での動作確認を含む)と、
7月に配偶者経由で得た既存分(2-1)で回答することとした。

**製品版アクセス申請前の状況**: 上記2件のクローズにより、Takatohの
判断が必要だった項目(年齢設定の不整合〈未完了項目6、2026-08-10(続2)
で解消済み〉・ライセンステスト登録の確認・テスターフィードバック再収集
の要否)はすべて解消した。**[要指摘]** ただし未完了項目4「統計情報の
共有」はテスター管理業者への契約上の約束(「外部サービス保証条件」)で
あり、Googleの製品版アクセス申請フォーム自体の設問ではないため、これを
含めて「申請前にクリアすべき項目がすべて解消された」と表現すると、
統計情報の共有がまだブロック中である実態と齟齬が生じる。正確には、
**Takatoh判断待ちの項目はすべて解消し、残るのは2026-08-14前後の
クローズドテスト完走待ち・`PRODUCTION_ACCESS.md`チェックリストの最終
確認・統計情報の共有(業者向け、進行中)である**。STATE.md/ROADMAP.md
双方にこの区別を明記した。

### 2026-08-10(続4) RevenueCat RTDN接続完了、返金時のPremium剥奪バグの発見と対応方針

**RTDN接続の完了**: RevenueCat RTDN(Real-Time Developer Notifications)
接続が完了した[確認済 2026-08-10、RevenueCatダッシュボード実画面]。
Topic ID `projects/voikerchat/topics/Play-Store-Notifications`、ステータス
「Connected to Google」(緑チェック)、Last received: 2026-08-10 4:04 a.m.
UTC(Play Consoleからのテスト通知を受信)。これによりSTATE.mdバックログ
「RevenueCat Android有効化」は①〜④+RTDN接続まで全完了となった。

**実施手順が事前調査と異なっていた**: `internal-docs/reports/
revenuecat_rtdn_investigation_20260807.md`(2026-08-07作成)は、①必要な
IAMロールは「Pub/Sub編集者」で十分 ②Pub/Subトピックは人間がGCP Console
で手動作成 ③`google-play-developer-notifications@system.gserviceaccount.com`
への発行者権限付与は人間が手動実行、と想定していたが、実際には①**Pub/Sub
管理者(`roles/pubsub.admin`)が必要**(「Pub/Sub編集者」ではトピックの
IAMポリシー変更権限が無く「Your Google service account credentials do not
have permission to create a Google Cloud Pub/Sub topic.」エラーで失敗)
②③**RevenueCatの「Connect to Google」操作が自動実行**、という点で異なって
いた。レポート本文を訂正し、当初の誤った想定は「3-旧」として記録に残した
(黙って書き換えない)。運用上の落とし穴として、GCPのロール検索で
「Pub/Sub Lite 管理者」(別サービス、無効)が「Pub/Sub 管理者」より先に
表示され誤って選択しやすい点も記録した。所要時間実測は約20分(権限エラーの
解決を含む)。

**返金時のPremium剥奪バグの発見**: RTDN接続作業と並行して
`api/revenuecat-webhook.ts`のコードレビューを行った結果、**返金が成立
してもPremiumが剥奪されない不具合**を発見した。RevenueCatには独立した
`REFUND`イベント種別が存在せず、返金は`CANCELLATION`イベントの
`cancel_reason='CUSTOMER_SUPPORT'`として届く(RevenueCat公式ドキュメント
「Event Types and Fields」で確認、2026-08-10、WebFetchで2回確認・内容
一致)。現状のコードは`REVOKE_EVENT_TYPES=EXPIRATION`のみで`CANCELLATION`
を一律`action='none'`として無視しており、返金後もPremiumが残り続ける。
`EXPIRATION`に頼ることもできない(返金後も自動更新設定が有効なままの
ことがあり、その場合はRENEWALが先に発火しEXPIRATIONが届かない)。

**2026-06の既存決定「CANCELLATIONでは降格しない。EXPIRATIONのみ降格」
との関係**: この決定は自発的解約(UNSUBSCRIBE)については**引き続き
正しい**。自動更新をOFFにしただけのユーザーは期間終了までPremiumを使う
権利があるという判断は変わらない。問題は、RevenueCatが「解約」と「返金」
を同一の`CANCELLATION`イベントに集約している点であり、2026-06時点では
この区別が考慮されていなかった。**本件の対応は既存決定の全面撤回では
なく、返金ケースに限定した例外の追加**である。

**修正方針**: `cancel_reason`をホワイトリスト方式で判定し、
`CUSTOMER_SUPPORT`(返金)と明示的に判定できた場合のみrevoke。
`UNSUBSCRIBE`(自発的解約)・`BILLING_ERROR`(猶予期間中の一時的な支払い
失敗、剥奪すると回復ユーザーの権利を誤って奪う)・`DEVELOPER_INITIATED`・
`PRICE_INCREASE`・`UNKNOWN`・値が無い場合は保守的にnoneのまま据え置く。
`cancel_reason`の全6値はRevenueCat公式ドキュメントで確認済み(実装前に
公式ドキュメントを再確認する運用に従った結果、チャット側Claudeが把握
していた3値〈BILLING_ERROR/UNSUBSCRIBE/CUSTOMER_SUPPORT〉に加え
DEVELOPER_INITIATED/PRICE_INCREASE/UNKNOWNの3値を新たに確認した。
ホワイトリスト方式のため未知の値も自動的にnoneへ倒れ、安全性への影響は
無い)。

**マージ方針**: 修正はPR #89(`fix/refund-cancellation-premium-revoke-
20260810`)として作成した。**Android Build 21が現在Google審査中であり、
コード変更を含むPRのマージはBuild 22以降にまとめて反映する方針のため、
PR #89はレビュー・記録用に作成のみでマージは保留する**。実際の返金
イベントによる動作検証は未実施(検証可能な生きた購読が現時点で存在しない
ため)。

**未解決の別件(RevenueCat上の購読レコード欠落)**: 上記の調査中に、
2026-08-06の開発者本人のライセンステスト購読(注文番号
`GPA.3366-1618-4848-35600`)がRevenueCat側に記録されていないことが
判明した。Customers → Active subscribers=0人、Expired=0人、Sandbox=4人
(いずれもentitlementsが無く購入イベントも未記録)[確認済 2026-08-10]。
Google Play側では購入が成立しているにもかかわらずRevenueCat側にレコードが
見当たらない状態であり、**原因は特定していない**(RTDN未接続だったこと・
8/7の実機検証でのアプリ削除/再インストールによる匿名user_id再生成・
ライセンステスト購読の短期終了、等がcandidateだが断定材料が無い)。実害は
開発者本人のテスト購読1件が追跡できないのみで、実ユーザー・収益への影響は
無いと評価した。この結果を受け、`internal-docs/ROADMAP.md`区分3の運用知見
(「ライセンステスト購読を検証に使う」)も、既存の8/6購読は使えない旨へ
訂正し、Build 21配信後に新規購入を行って検証する方針へ更新した。

### 2026-08-10(続5) 競合追加調査(ELSA/スピークバディ)と販促方針の決定

**競合追加調査の結論**: 英語学習AIアプリ(ELSA Speak / スピークバディ)の
レビュー記事(https://www.academianote.site/elsa-vs-speakbuddy-review/、
https://nothing-without-poison.com/hack15/、いずれもアフィリエイト/PR記事、
評価部分は割り引く必要あり、[未検証])を調査した。詳細は
`internal-docs/Competitor-Insights.md`(旧`Competitor-Insights-202607.md`から
`git mv`でリネーム、2026-07初版/2026-08-10追補の2節構成に再編)参照。

**7月版の価格評価を年額プランの観点から修正**: 7月版は「Voikerchat $12.99/月
(≒年$156)は競合の年$60〜190の上限付近」としていたが、月額同士で比較すると
Voikerchat(1,818円)は競合(スピークバディ3,980円/ELSA 3,380円)の半額程度と
競争力がある。ただし競合は年額契約が主力(月換算2,316〜2,367円)であり
Voikerchatに年額プランが無いため比較の土俵に乗れていなかったことが7月時点の
評価差の原因と考えられる[推測]。**結論: 価格は競争力があるが、年額プランの
不在が構造的な弱点**。7月版の記述は削除せず、訂正の経緯として本ファイル内に
明示した。

**ELSAの教育機関導入という先行事例**: ELSAが国内の教育機関(関西大学ほか)に
導入され始めていることを確認した。「個人向けで立ち上げ→実績を積んで教育機関へ
横展開」という道筋が英語学習領域で成立している先行事例であり、Voikerchatの
B2B・機関向けを本命とする既存方針(2026-08-07決定)を裏付ける材料として
`internal-docs/ROADMAP.md`区分4へ反映した。

**公開直後の着手対象を2件に絞った判断**: `internal-docs/ROADMAP.md`区分4へ
5項目(年額プラン追加・学習スコア可視化・無料トライアル・ユーザー定義シーン・
在日フィリピン人向け実用シーン追加)を追加したが、公開直後に着手するのは
**「年額プランの追加」**(実装コストが小さい割にLTV・キャッシュフローへの
効果が大きい)と**「学習スコアの可視化」**(第一段階は追加のAI呼び出しなしで
実装できる範囲=会話数・連続日数・使用語彙数に限定し、トークンコストゼロで
効果を狙う)の2件に絞った。無料トライアル・ユーザー定義シーンはトークン
コスト増や不適切なシーン設定への対策が必要なため公開後・運用が落ち着いてから、
実用シーン追加は7月版で既にニッチとして定義済みの内容の具体化として継続扱いとした。

**販促方針: SNSより「ストア掲載情報」「初日レビュー獲得」を優先**:
`internal-docs/GROWTH_PLAN.md`を新設した。アプリの流入の大半はストア内検索
であるため、SNSでの集客より先に①ストア掲載情報の最適化(ASO、PR #20の反映を
含む。`internal-docs/ROADMAP.md`区分3から区分2へ格上げ)②公開初日のレビュー
獲得(配偶者経由の実テスター16名へ公開日に依頼)を優先する。ストアの
ランキングは初期のレビュー数と速度に強く影響される[一般論、要検証]ため、
新規流入100人より初日の★4〜5が15件のほうがランキング上効く可能性が高いという
判断による。

**SNSはFacebook一本に絞る判断とその理由**: フィリピン向けにはFacebookが
主戦場(フィリピンでのFacebook利用率の高さ、在日フィリピン人コミュニティ
グループがFacebook上に多数存在すること、いずれも[未検証・一般認識ベース])。
TikTok/Instagram/Xは採用しない。個人開発で公開直後の不具合対応をしながら
複数プラットフォームを同時運用するのは不可能であり、**放置されたアカウントは
無いより悪い**(最終投稿が3ヶ月前だと「もう終わっている」印象を与える)ため、
続けられる分だけに絞った。事業の本命が機関・窓口である以上、SNSの役割は
バズではなく「導入検討時に検索されたとき、活動している形跡があること」に
近いという位置づけで、月1〜2回の更新を想定する。

**`sns_playbook.md`はTokyo Bible向けで陳腐化している事実**: `shibuyer-ops/
sns_playbook.md`(SNSショート動画運用プレイブックv1.0)はTokyo Bible
(2026-07に終売決定済み)向けの内容(TikTok中心・英語のみ・インバウンド観光客
向け)であり、Voikerchat(日本語学習アプリ・在日フィリピン人向け)には
プラットフォーム・言語・コンテンツのいずれも一致せず流用できない。`internal-
docs/GROWTH_PLAN.md`に陳腐化している旨を注記した。`shibuyer-ops`リポジトリ
側のファイル自体は本件では変更していない。
