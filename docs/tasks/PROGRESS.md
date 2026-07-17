# PROGRESS — Phase A 品質ゲート進捗台帳

運用ルールは RUNBOOK.md 参照。ここが現在地の唯一の真実。

## タスク状態
- [x] T-30 ブランドカラー・テーマ刷新 完了 2026-07-17 commit 31e5228 / CI緑(29545734528, 29545734646)
- [x] T-33 プレミアム購入フロー(ペイウォール) 完了 2026-07-17 commit 778a912 / CI緑(29546248589, 29546248599)
- [x] T-34 プレミアム専門シーン5本 + Kaigotalk データ設計 完了 2026-07-17 commit f55e500 / CI緑(29546593781, 29546593782)
- [x] T-32 シーンカード キャラクター画像 完了 2026-07-17 commit 7109444 / CI緑(29547467704, 29547467680)
- [x] T-36 学習サポート移植(ふりがな/ヒント/単語まとめ) 完了 2026-07-17 commit d2fdaaa / CI緑(29554642149, 29554642202)
- [x] T-31 単語タップ辞書機能 完了 2026-07-17 commit 9cd031d / CI緑(29547891381, 29547891450)
- [x] T-35 高品質TTS(3段構成: 端末/広告日解放/プレミアム常時) 完了 2026-07-17 commit ca80ee2 / CI緑(29549450659, 29549450661)

## 人間へのお願い(未処理)
- [x] ~~Gemini でキャラ画像18枚生成~~ **完了 2026-07-17**: Google Drive
  (`Voikerchat_Development/Character_icon/`)の18枚を512×512 WebP(quality=80)に変換して
  `assets/characters/` に配置済み(commit `7fa44e2`)。**残作業(人間)**: シーン選択画面で
  各カードの画質・構図を目視確認(元がAI生成2048×2048 PNGをリサイズ・再圧縮したもの、
  自動変換のため画質チェック未実施)
- クローズドテスト(Android)のトラック開始 — 14日の時計を先に回す(Master Plan 方針)
- T-33: Sandbox/ライセンステスターでの実機購入・復元テスト
- T-34: 新シーン14〜18(介護のしごと/医療スタッフ/面接/役所・手続き/職場の敬語)を各3往復以上
  実機/シミュレータで会話し、口調・語彙レベルが仕様通りか確認(受け入れ基準の手動確認項目)
- T-31: AIメッセージのテキスト選択→「意味を調べる」→ボトムシート表示のUXを実機/シミュレータで
  一度確認(受け入れ基準「2秒以内表示」「入力欄・TTS再生が壊れない」の体感確認)
- [x] ~~T-35: `docs/migrations/2026-07-17_lock_rate_limits_client_write.sql` をSupabase SQL Editorで実行~~
  **完了 2026-07-17**(ユーザーがSQL Editorで手動実行、"Success. No rows returned"を確認)。
  `rate_limits` へのクライアント直接UPDATEを許可していたRLSポリシー("System can update rate limits")を削除。
  以後、広告視聴ボーナス付与は `api/ad-reward.ts`(service role)経由のみで可能。
- [x] ~~T-35: OpenAI APIキー取得 → Vercel環境変数 `OPENAI_API_KEY` に設定~~ **完了 2026-07-17**:
  Vercel CLI(`vercel env add`)で `voikerchat-x621` の Production/Preview/Development 全環境に設定し、
  最新デプロイをredeploy(dpl_2ioDzc97gYFEGfcZLjmZ89vy7Gcz → voikerchat.comへエイリアス済み)。
  `curl https://voikerchat.com/api/tts` に不正トークンで実行し、「Server misconfiguration」ではなく
  「Invalid or expired token」が返ることを確認(=環境変数は正しく読み込まれている)。キー自体はDrive
  `00_Project_Credentials` への保管が未実施(人間の残作業)。
- T-35: 実機での聴感・レイテンシ確認、3段切替(端末→広告視聴→即日クラウド→日付変更で端末に戻る)の動作確認、
  機内モードでのフォールバック確認、`curl`でのAPI直叩き拒否確認(仕様書の受け入れ基準)
- 広告視聴のAdMob SSV(真正性検証)は今回未対応。docs/tasks/BACKLOG-Phase2.md #11 参照(Phase2で検討)
- (継続) セキュリティ注意: `C:\Users\takat\Documents\voikerchat` のgit remote URLに
  GitHub PATが平文で埋め込まれている件は、クローンをユーザー側で削除する方針・トークンローテーションは見送りで対応済み(2026-07-17)
- T-36: ふりがな表示(トグルON時)・ヒントボタン・単語まとめ(3往復以上で会話終了/消去時に表示)の
  UXを実機/シミュレータで一度確認(受け入れ基準: ふりがなON時の表示+読み上げが二重にならないこと、
  ヒントが2秒以内目安で出ること、単語まとめが3往復以上で表示・0〜2往復でスキップされること)
- **Play Console クローズドテスト開始**(14日タイマー律速。人数確定を待たずに開始可、Master Plan方針)

## 判断記録
- T-30 ブランドカラー: ユーザー確認の結果、アイコン(assets/icon/app_icon_1024.png)から抽出した主要色を採用(候補A/B/C不採用)。抽出精度を上げた結果の正確な値 `#C73E3A` を採用(ユーザー承認時点の概算値は#C0392B)。
- T-30 スプラッシュ背景色: 仕様書は「決定色またはアイコン背景色の維持」を設計判断事項としていたため、彩度の高いブランド色ではなくアイコン自体の背景色 `#FAF7F0`(生成り)を採用し、アイコン→スプラッシュの視覚的連続性を優先(軽微な判断のため自己決定)。
- T-30 旧「Voikerchatブルー」(`#0099FF`、onboarding_progress_bar / diagnostic_test_screen_enhanced 等に散在)は明示的にブランド色扱いだったため、新ブランド色 `AppColors.brand` に統一置換。
- T-30 git identity: このリポジトリ限定で `.git/config` の `user.email` を `262262561+shibuyer-jp@users.noreply.github.com` にローカル上書き(CLAUDE.md指定、Vercelデプロイブロック回避目的)。global設定は変更していない。
- T-33 revenuecat_service.dart のバグ修正: `restorePurchases()` が実際には `Purchases.getCustomerInfo()` を呼んでおり復元処理を行っていなかった。`Purchases.restorePurchases()` を呼ぶよう修正(仕様書に明記はないが受け入れ基準「復元が機能する」に必須のため軽微な判断で修正)。
- T-33 home_screen.dart のバグ修正: `HomeScreen(userLevel: ...)` 呼び出し側(main.dart)が `isPremiumUser` を一切渡しておらず常に `false` だった(=購入済みユーザーでもシーンがロック表示されたままになる不具合)。RevenueCatServiceの実エンタイトルメントから取得するよう変更。
- T-33 chat_screen.dart 内蔵の購入ダイアログ/処理(`_showPremiumDialog`/`_purchasePremium`等)は全てPaywallScreen遷移に統一し削除(仕様書の「既存導線もPaywallScreenへ接続」に対応)。
- T-34 プレミアムシーンの実用/アニメ2分類は `SceneService` に `id>=14` の判定を集約(UI層に直書きしない)。
- T-34 Kaigotalkデータ設計: `usage_logs.session_id` が現状クライアントから送信されておらず常にNULLのため、正確な「完走率・平均ターン数」はセッション単位集計ができない。日次のuser×scene集計で近似するSQLをdocs/Kaigotalk-Data-Queries.mdに記録し、正確な計測が必要になった場合はsession_id送信の追加実装が別途要ることを明記(新規テーブル/スキーマ変更はしない方針を優先)。
- T-32 `assets/characters/` が空だと `flutter build`(Gradle)が `unable to find directory entry` を出す(pub getは通るがbuildは出る)ことを実機検証で確認。命名規約を記したREADME.mdを配置してディレクトリを非空に保つことで回避(新規判断・軽微)。
- T-31 辞書機能の日次クォータは `usage_logs` の既存 `event`('message_sent')を再利用し `metadata.feature='define'` で識別する設計にした(仕様書の「event typeは既存の汎用のものを使いスキーマ変更はしない」指示に従う)。ただし `docs/Kaigotalk-Data-Queries.md` のシーン別ターン数集計クエリは、辞書呼び出しが `message_sent` としてカウントされるため、`metadata->>'feature'` が `'define'` でない行に絞る必要がある(未反映、次回T-34クエリ見直し時に対応)。
- T-31 api/define.ts は既存 api/chat.ts の mode追加ではなく新規ファイルとした(1エンドポイント1ファイルの既存アーキテクチャに合わせるため。認証/エラーハンドリングの一部処理はchat.tsと重複するが、chat.tsの動作実績あるコードに手を入れるリスクを避けた)。
- T-35 着手前に発見した設計上の懸念点はユーザー確認の上で対応: `grantAdBonus()`(rate_limit_service.dart)を
  クライアント直接Supabase書き込みから `api/ad-reward.ts`(service role)経由に変更し、
  usage_logs.ad_reward記録とrate_limits更新をサーバーだけで行うようにした。あわせて
  クライアントのrate_limits直接UPDATEを禁止するRLS変更SQLを用意(人間がSupabase SQL Editorで実行)。
  AdMobのSSV(広告視聴自体の真正性検証)まではスコープに含めず、BACKLOG-Phase2.md #11へ登録。
- T-35 クラウドTTSの日次解放判定は `usage_logs.ad_reward` の当日件数(UTC日付基準、rate_limitsの
  日次リセットと同一ロジック)をapi/tts.ts側で検証。クライアントの `CloudTtsUnlockService` はUI表示・
  無駄な通信回避のためのローカルヒントに過ぎず、実際の許可はサーバーが握る。
- T-35 キャラクター音声(18キャラ→OpenAI音声ID)の割当は `lib/constants/character_voice_map.dart` に集約し
  `api/tts.ts` 側にも同じ表を複製(サーバーがvoiceを決定するため。声の数(6種)よりキャラが多いため一部重複)。
- T-35 usage_logs.event の再利用により、T-31(`feature:'define'`)・T-35(`feature:'cloud_tts'`)ともに
  `message_sent` として記録される。docs/Kaigotalk-Data-Queries.md の集計クエリに
  `metadata->>'feature' is null` フィルタを追加し、会話ターン数を誤集計しないよう修正済み。
- T-32 キャラ画像18枚: Google Driveに置かれていた元ファイルは拡張子が`.webp`でも中身は
  全て2048×2048のPNG(1枚3〜5MB、18枚合計約65MB)で、仕様書の目標(512×512 WebP、
  合計~1MB)から大きく乖離していた。ユーザー確認の上、Pillow(ローカルにWebP保存対応
  環境あり)で512×512・quality=80のWebPへリサイズ・再変換して配置(元PNGはDrive上に
  残置、不可逆変換ではない)。変換後サイズ(KB):
  scene_01=31.0, scene_02=17.1, scene_03=21.1, scene_04=17.1, scene_05=19.3,
  scene_06=15.3, scene_07=16.1, scene_08=22.2, scene_09=27.9, scene_10=28.6,
  scene_11=22.7, scene_12=18.0, scene_13=27.3, scene_14=23.5, scene_15=20.4,
  scene_16=14.6, scene_17=17.2, scene_18=17.4。**合計 376.6KB**(目標~1MB以内を達成)。
  画質の目視確認(自動変換のため)は人間の残作業として上記に記載。
- T-36 ヒント機能のクォータはT-31辞書機能と合算(仕様書指示通り)。api/define.tsのクォータ判定を
  `metadata->>feature = 'define'`単独から`metadata->>feature in ('define','hint')`に変更し、
  api/hint.ts側にも同じ合算判定を実装(上限値`FREE_DAILY_DEFINE_HINT_LIMIT=30`を両ファイルで定義。
  実際のカウントロジックはdefine.ts/hint.tsそれぞれが独立して同じクエリを実行するため、
  上限値さえ一致していれば重複定義による不整合は生じない)。
- T-36 単語まとめの表示トリガーは「会話を終了」「会話を消去」の2箇所のみに実装(ハードウェア/OS
  標準の戻るジェスチャーは対象外、既存のセッション終了導線がこの2つのみだったため)。
  会話終了フローでは、単語まとめボトムシート表示中(長いawait)にオプションシートのcontextが
  破棄される問題があったため、NavigatorState参照を先に確保してから使い回す実装にした。
- T-36 単語まとめ(vocab_summary)・T-35クラウドTTS(cloud_tts)・T-31辞書(define)・T-36ヒント(hint)は
  いずれも`event='message_sent'`を再利用するため、docs/Kaigotalk-Data-Queries.mdの
  `metadata->>'feature' is null`フィルタは4機能すべてを包括的に除外できている(機能追加のたびに
  フィルタ側の修正は不要な設計)。

## セッションログ
- 2026-07-16: 計画策定(claude.ai 側)。仕様書 T-30〜T-35 / Master Plan v2.0 / RUNBOOK 作成。
- 2026-07-17: T-30 完了。commit `31e5228`、CI緑(CI/CD - Voikerchat run 29545734528, Flutter CI run 29545734646)。
- 2026-07-17: T-33 完了。commit `778a912`、CI緑(CI/CD - Voikerchat run 29546248589, Flutter CI run 29546248599)。
- 2026-07-17: T-34 完了。commit `f55e500`、CI緑(CI/CD - Voikerchat run 29546593781, Flutter CI run 29546593782)。
- 2026-07-17: T-32 完了。commit `7109444`、CI緑(CI/CD - Voikerchat run 29547467704, Flutter CI run 29547467680)。
- 2026-07-17: T-31 完了。commit `9cd031d`、CI緑(CI/CD - Voikerchat run 29547891381, Flutter CI run 29547891450)。
  T-35着手前にセキュリティ懸念(広告視聴ボーナスの検証可能性)をユーザーに確認。
- 2026-07-17: セキュリティ強化(T-35前提)完了。commit `0314669`、CI緑(29548757025, 29548757041)。
  grantAdBonusをapi/ad-reward.ts経由化、rate_limits直接UPDATE禁止のRLS変更SQLを用意(人間の実行待ち)。
- 2026-07-17: T-35 完了。commit `ca80ee2`、CI緑(CI/CD - Voikerchat run 29549450659, Flutter CI run 29549450661)。
- 2026-07-17: T-32のキャラ画像18枚を配置。commit `7fa44e2`、CI緑(CI/CD - Voikerchat run 29550291285,
  Flutter CI run 29550291281)。Google Drive上のPNG(拡張子偽装)を512×512 WebPへ変換して配置
  (詳細は「人間へのお願い」「判断記録」参照)。
- 2026-07-17: OpenAI APIキーをVercel(voikerchat-x621)のProduction/Preview/Developmentに設定し
  最新デプロイをredeploy。api/tts.tsがServer misconfigurationを返さないことをcurlで確認。
- 2026-07-17: ユーザーがSupabase SQL Editorで `docs/migrations/2026-07-17_lock_rate_limits_client_write.sql`
  を実行完了("Success. No rows returned")。T-35の前提となるセキュリティ強化(サーバー経由化+RLS制限)が
  コード・DB両面で完了。※このPROGRESS.md編集はAPI切断でローカル未pushのまま残り、次セッション冒頭で
  commit `a71f294` として回収・push。
- 2026-07-17: shibuyer-ops/memory/handoff_20260717_1.md の引き継ぎに従いセッション再開。
  取りこぼし回収(上記commit `a71f294`)後、T-36(学習サポート移植)に着手。
  ふりがな表示トグル・ヒントボタン・単語まとめボトムシートの3機能を実装、commit `d2fdaaa`、
  CI緑(CI/CD - Voikerchat run 29554642149, Flutter CI run 29554642202)。

**Phase A 品質ゲートのコードタスク7件(T-30/31/32/33/34/35/36)は全て完了・CI緑。
T-35を実際に動かすための人間側の前提作業(OpenAIキー設定・RLS変更)も両方完了。
残るのは実機/目視確認とストア操作(下記「人間へのお願い」)のみ。**

## 次アクション(次回セッション)
- コード側の未着手タスクはなし。残る「人間へのお願い」(実機確認・目視確認・ストア作業系)を
  上記リストから消化していくフェーズ。特に **Play Console クローズドテスト開始**(14日タイマー)は
  他の作業をブロックする律速要因のため優先度が高い。
- 実機確認が一通り終わったら、Phase B(スクリーンショット再撮影・プライバシーポリシー確認)→
  Phase C(提出)へ進む(docs/Release-Master-Plan-v2.0.md参照)。
