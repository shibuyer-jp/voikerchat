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
