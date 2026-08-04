# キャラクター画像アセット(T-32)

`scene_preview_card.dart` がシーンごとに読み込む画像。ファイル名は zero-padded 2桁の
シーンIDで固定(`scene_01.webp` 〜 `scene_18.webp`)。仕様は
`internal-docs/tasks/T-32_character-images.md` 参照(生成プロンプト雛形あり)。

- 形式: WebP(透過)、512×512px、1枚あたり50KB目安(`cwebp -q 80`)
- 未生成のシーンはファイルを置かない(`ScenePreviewCard` がキャライニシャル+
  アクセント色のプレースホルダーへ自動フォールバックする。壊れない)。
- このファイル(README.md)自体は画像として読み込まれない
  (`Image.asset` は `scene_NN.webp` という名前でのみ参照する)。
