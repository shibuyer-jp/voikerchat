# T-30: ブランドカラー確定とテーマ刷新

## 目的
現状 `lib/main.dart` の `ColorScheme.fromSeed(seedColor: Colors.blue)`(Flutter既定の青)とスプラッシュ背景 `#ffffff`(仮置き、STATE.md 参照)を、製品版にふさわしいブランドテーマへ置き換える。

## 人間の判断が必要な点(最初に確認)
ブランドカラーの最終決定。候補3案(ターゲット=フィリピン人の日本語学習者、明るく前向きな学習体験):
- A案 ティール `#00897B`: 落ち着き+信頼。教育系で定番、既存の緑系レベルタグと調和
- B案 コーラル `#FF6F61`: 温かく親しみやすい。会話アプリらしい人懐こさ
- C案 インディゴ `#3F51B5`: 現状の青の延長で移行が自然、知的な印象
ユーザーがアイコン素材(`assets/icon/app_icon_1024.png`)を持つため、**アイコンの主要色から抽出して合わせるのが最優先**。Claude Code はまずアイコンPNGの主要色を抽出して提示すること。

## 実装手順
1. `lib/theme/app_theme.dart` を新設し、ThemeData を集約(seedColor 定数、AppBarTheme、Card、SnackBar、ボタン形状)。`main.dart` からは `AppTheme.light` を参照するだけにする。
2. 色のマジックナンバー散在を排除: `scene_preview_card.dart` の `_getLevelColor` 等、直書き Color を `lib/theme/` の定数に集約(CLAUDE.md のマジックナンバー方針に準拠)。
3. `flutter_native_splash` の背景色を仮置き `#ffffff` からブランド決定色(または白のまま正式承認)に更新し、`dart run flutter_native_splash:create` を再実行。
4. シーンごとの `Scene.color` はカードのアクセント(左ボーダー等)として活かすか廃止するかを設計判断し、統一する。
5. 全画面(シーン選択/チャット/バッジ/統計/通知/設定/オンボーディング)を起動して目視スクショを撮り、コントラスト崩れがないか確認。

## 受け入れ基準
- `Colors.blue` 直参照が main.dart から消え、テーマが1ファイルに集約されている
- `flutter analyze` / `flutter test` 緑
- ライトモードで全画面のテキストコントラストが確保されている(WCAG AA 目安)

## 影響範囲の注意
テーマ変更後、**撮影済みストアスクリーンショットは全て再撮影対象**(Master Plan Phase B)。
