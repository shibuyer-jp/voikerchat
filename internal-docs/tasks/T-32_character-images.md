# T-32: シーンカードにキャラクター画像を表示

## 目的
シーン選択画面のカード右側の空白領域(スクショ赤枠部分)に、シーンに沿ったキャラクター画像を表示する。現状 `scene_preview_card.dart` に画像スロットはなく、画像アセットも存在しない。

## アセット仕様(人間側: 画像生成の実行が必要)
- 形式: WebP(透過)、512×512px、1枚あたり 50KB 目安(`cwebp -q 80`)
- 配置: `assets/characters/scene_01.webp` 〜 `scene_18.webp`(T-34 の新シーン含め18枚)
- スタイル統一: 明るいアニメ調・バストアップ・背景透過・同一タッチ(全キャラを同一セッション/同一スタイル指定で生成すること)
- **著作権注意: 既存アニメ・実在人物に似せない。完全オリジナルのキャラクターとする。**

### 生成プロンプト雛形(画像生成AIに投入)
共通接頭辞: `anime style, bust-up portrait, transparent background, bright friendly colors, clean line art, original character, `
| scene | キャラ | 追加指定 |
|---|---|---|
| 01 友達 | Sakura | cheerful young woman, casual clothes |
| 02 レストラン | Takuya | polite young waiter, black apron |
| 03 買い物 | Yumi | friendly shop clerk woman |
| 04 電車 | Kouki | young man in commuter attire |
| 05 病院 | Akari | kind nurse woman, pastel uniform |
| 06 自己紹介 | Kenji | confident businessman, suit |
| 07 カフェ | Minato | relaxed barista man, cafe apron |
| 08 フリートーク | Eiko | warm middle-aged teacher woman |
| 09 熱血戦闘 | Raiki | fiery spiky-haired hero boy |
| 10-13 アニメ残り | (scene_service.dart の記載に合わせる) | 各キャラ性に沿って |
| 14-18 専門シーン | T-34 参照 | 各キャラ性に沿って |

## 実装手順(Claude Code)
1. `pubspec.yaml` に `assets/characters/` を追加。
2. `ScenePreviewCard` にサムネイル表示を追加: カード右側に 88dp 角丸の `Image.asset`。**画像が無いシーンはキャライニシャル+シーン色のプレースホルダーを表示**(アセット到着前でも壊れないフォールバック必須)。
3. ロック中プレミアムシーンは画像を半透明+ロックアイコン重ねで「見せて欲しがらせる」。
4. チャット画面のヘッダー(またはアバター)にも同画像を小さく再利用(任意・工数次第)。
5. アプリサイズ確認: 18枚合計 ~1MB 以内に収まることを確認。

## 受け入れ基準
- 全シーンカードに画像またはプレースホルダーが表示され、レイアウト崩れなし(スマホ/タブレット両方)
- `flutter analyze` / `flutter test` 緑
- 画像追加後にゴールデンテスト等既存テストが壊れていない
