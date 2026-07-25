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
