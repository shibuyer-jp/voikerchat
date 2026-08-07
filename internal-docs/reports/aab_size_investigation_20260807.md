# AABサイズ(89.4MB)の調査(2026-08-07)

## 調査方法

Build 18(`versionCode 18`)ビルド時に実際に生成され、ローカルに残っていた
`build/app/outputs/bundle/release/app-release.aab`(93,704,993 bytes =
89.36 MiB。Play Consoleの「89.4MB」表記と一致)を直接展開し、Pythonの
`zipfile`モジュールでエントリ単位の圧縮後サイズを集計した(AABはZIP
形式のため展開・集計が可能)。実測に基づく調査であり、推測を含まない。

## 内訳(圧縮後サイズ、降順)

| 区分 | 圧縮後サイズ | 生サイズ | ファイル数 | ユーザー端末に配信されるか |
|---|---|---|---|---|
| `BUNDLE-METADATA/debugsymbols` | 28.47 MiB | 74.37 MiB | 9 | **されない**(Play Consoleのクラッシュ解析専用) |
| `assets/onboarding/`(9枚、3言語×3枚) | 26.28 MiB | 31.11 MiB | 9 | される(全言語分が全端末へ) |
| `lib/x86_64/`(ネイティブライブラリ) | 8.39 MiB | 20.12 MiB | 4 | 通常されない(x86_64端末のみ) |
| `lib/arm64-v8a/` | 8.21 MiB | 18.73 MiB | 4 | される(64bit ARM端末) |
| `lib/armeabi-v7a/` | 7.85 MiB | 16.53 MiB | 4 | される(32bit ARM端末のみ) |
| `dex/`(Dalvikバイトコード) | 5.09 MiB | 12.38 MiB | 3 | される |
| `BUNDLE-METADATA/obfuscation`(R8マッピング) | 3.82 MiB | 40.48 MiB | 1 | **されない**(Play Console専用) |
| `assets/characters/`(キャラクター画像19枚) | 0.37 MiB | 0.37 MiB | 19 | される |
| その他(res/フォント/manifest等) | 約0.6 MiB | 約1.5 MiB | 多数 | される |
| **合計** | **89.36 MiB** | **215.7 MiB** | 496 | — |

(内訳の算出スクリプトは本レポート末尾に添付)

## 重要な発見: 「89.4MB」の3分の1超はユーザーに一切配信されない

`BUNDLE-METADATA/`配下(debugsymbols + obfuscation)は**32.29 MiB、
全体の36%**を占めるが、これはAndroid App Bundleの仕様上、Google Play
側でネイティブクラッシュ・難読化解除の解析にのみ使われる添付データで
あり、**エンドユーザーの端末には一切ダウンロード・インストールされない**。
`android/app/build.gradle.kts`を確認したが`nativeDebugSymbolLevel`等の
明示設定は無く、Android Gradle Pluginのデフォルト動作としてリリース
ビルド時に自動生成されているだけで、誰かが意図して同梱した設定ではない。

**確認事項(Takatoh、Play Console実画面)**: 「サイズ増加の警告」が
Play Consoleのどの画面・どの数値(アップロードしたAABファイル自体の
サイズか、「App bundle explorer」が示す端末別ダウンロードサイズか)を
指しているかで、この36%がそもそも警告の対象に含まれているかが変わる。
含まれていなければ、以下の削減提案のうちEのみで警告が解消する可能性
がある。

## ネイティブライブラリ(lib/)についての補足: AAB合計 ≠ 実際のダウンロードサイズ

`lib/`配下は3つのABI(arm64-v8a・armeabi-v7a・x86_64)分、合計24.46 MiB
が同梱されているが、Android App BundleはGoogle Playのdynamic delivery
機構により、**1台の端末につき自身のABIに対応する1つのディレクトリのみ**
が実際に配信される(ユニバーサルAPKとは異なる)。したがって「AABの
合計サイズ」と「実際のユーザーのダウンロードサイズ」は同一ではなく、
89.4MBという数字はユーザー体感のダウンロードサイズを表していない。

x86_64はChromebook/x86系タブレット・エミュレータ向けであり、一般的な
Androidスマートフォン(実利用ターゲット)はarm64-v8aかarmeabi-v7aの
いずれかを受け取る。

## 削減案(工数見積もり付き)

### A. オンボーディング画像のWebP変換(推奨・最優先)

- **内容**: `assets/onboarding/`の9枚のPNG(1536×2752、RGBA)をWebP
  (lossy, quality 80〜85程度)へ変換する。`Image.asset()`はWebPを
  ネイティブにサポートしており、コード変更は`pubspec.yaml`のパス
  拡張子変更のみで済む
- **見積もり削減量**: 写真・イラスト調の画像に対するWebPの一般的な
  圧縮率(PNG比50〜70%減)を踏まえると、26.28 MiB → 概算8〜13 MiB
  程度まで圧縮可能と推定(**AAB合計から約13〜18 MiB、15〜20%の削減**)
- **工数**: **S(半日以内)**。`cwebp`コマンド(または類似ツール)で
  9枚を変換 → 3言語×3枚で目視品質確認(文字が含まれる画像のため
  文字の可読性を重点確認) → `pubspec.yaml`のアセットパス更新 →
  実機/シミュレータで表示確認
- **リスク**: lossy圧縮による文字部分のにじみ。quality値を上げて
  再調整すれば対処可能。iOS側にも同じ効果があるため両OSで恩恵あり

### B. PNGのまま圧縮を強化(Aの代替・より低リスク)

- **内容**: フォーマット変更をせず、`pngquant`やOxiPNG等でPNGの
  ロスレス/準ロスレス圧縮を強化する
- **見積もり削減量**: PNG最適化ツールで一般的に見込める30〜40%減を
  想定すると、26.28 MiB → 概算16〜18 MiB(**AAB合計から約8〜10 MiB、
  9〜11%の削減**)。Aより効果は小さいがコード変更・表示検証が不要
- **工数**: **XS(1〜2時間)**。既存PNGファイルの置き換えのみ
- **備考**: AとBは排他ではなく、Bで様子を見てから必要ならAへ進む
  段階的な進め方も可能

### C. 言語別アセット配信(Play Feature Delivery / Asset Pack)

- **内容**: 現状、`assets/onboarding/`の9枚(3言語分)は言語に関わらず
  全端末へ配信される。Play Feature Delivery(条件付きアセットパック、
  デバイスの言語設定によるconditional delivery)を使えば、該当言語の
  3枚のみを配信できる
- **実装上の制約**: Flutterの`pubspec.yaml`の`assets:`宣言は素朴に
  ベースモジュールへ全アセットを同梱する仕組みしか持たず、Flutter単体
  では言語別アセットパックの一級サポートが無い。実現するには以下
  いずれかが必要:
  1. **ネイティブAndroid側にアセットパック(Dynamic Feature Module)を
     新設し、Platform Channel経由でFlutter側から該当言語の画像バイト列
     を取得する**構成に作り替える(Android側のネイティブ実装が必要)
  2. **オンボーディング画像をアプリ同梱からCDN配信(Supabase Storage/
     Vercelでホスティング)へ切り替え、初回起動時に該当言語の3枚のみ
     ダウンロード・キャッシュする**構成に変更する(iOS/Android共通の
     実装で済み、既存のFlutterコードとの親和性が高い)
- **見積もり削減量**: 実際のユーザーのダウンロードサイズから最大
  約17.5 MiB(3言語中2言語分)を削減できる。ただし方式1はAABの
  「合計サイズ」自体はほぼ変わらない(配信の最適化のみ)。方式2は
  AABから画像自体を除去するため合計サイズも大きく下がる
- **工数**: **L(2〜3日、方式1)/ M(1日程度、方式2)**。方式2は
  2026-08-06にPR #59で修正済みの「オフライン時の白画面」問題との
  兼ね合いに注意が必要(初回起動時にオンボーディング画像を取得できない
  オフライン環境でのフォールバック表示を別途用意する必要がある)
- **判断**: 費用対効果と実装複雑度を踏まえ、AAB削減の即効性が求められる
  現段階ではA/Bを優先し、Cは一般公開後の中期的な改善候補と位置づけるのが
  妥当

### D. 不要なネイティブアーキテクチャ(x86_64)の除外

- **内容**: `android/app/build.gradle.kts`の`defaultConfig`に
  `ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }`を追加し、
  x86_64向けビルドを除外する
- **見積もり削減量**: x86_64の`lib/`(8.39 MiB)と、対応するデバッグ
  シンボル(debugsymbolsの約1/3、概算9.5 MiB)を合わせて**AAB合計から
  約18 MiB、20%の削減**が見込める。**ただし、実際のスマートフォン
  ユーザーのダウンロードサイズには影響しない**(x86_64は元々Play の
  dynamic deliveryで一般的なスマホには配信されていないため)。効果は
  「Play Console上に表示されるAABサイズの数字を下げる」ことに限られる
- **工数**: **XS(30分程度)**。設定追加のみ、CI(`ci-cd.yml`/
  `Build Android(debug)`)への影響有無を確認
- **判断材料**: x86_64はChromebook/x86タブレット・エミュレータ向け。
  本アプリがChromebook等の対応を明示的な要件としていなければ除外して
  差し支えない(未確認、Takatoh判断が必要)。Play Consoleの「端末カタログ」
  で既存テスターにx86_64端末が含まれていないか確認してから実施すること

### E. ネイティブデバッグシンボルの扱いを見直す(慎重に)

- **内容**: `android/app/build.gradle.kts`の`bundle { }` DSLで
  `nativeDebugSymbolLevel`を明示的に`NONE`等へ下げれば、
  `BUNDLE-METADATA/debugsymbols`(28.47 MiB)を削減できる
- **トレードオフ**: この領域はユーザーには配信されないため、**削減して
  もユーザー体感のダウンロードサイズは1バイトも変わらない**。一方で
  Play Vitals/Crashlyticsによるネイティブクラッシュのシンボル化(スタック
  トレースから原因箇所を特定する機能)が失われる。**「Play Console上の
  AABサイズの数字」だけを下げたい場合の手段であり、ユーザー体験の改善には
  寄与しない**ことを理解した上で判断すること
- **工数**: **XS(15分程度)**。ただし判断自体に時間をかけるべき項目
- **推奨**: まずはPlay Consoleの警告が具体的に何を指しているかを
  確認事項(上記)で切り分けてから、必要性を判断する

## 推奨する着手順序

1. **確認事項**: Play Consoleの「サイズ増加の警告」が具体的に何を指す数値か確認(Takatoh)
2. **B(PNG圧縮強化)**: 低コスト・低リスクでまず着手、効果測定
3. **A(WebP変換)**: Bで足りなければ実施。iOS側の恩恵もあるため優先度高
4. **D(x86_64除外)**: Chromebook対応が不要と確認できれば実施(Play Console上の数値のみ改善)
5. **C(言語別配信)**: 一般公開後、実際のダウンロード離脱率等のデータを見てから中期対応として検討
6. **E(デバッグシンボル)**: A〜Dで十分な削減が得られない場合の最終手段。クラッシュ解析能力とのトレードオフを踏まえて判断

## 参考: iOS Build 17との比較について

iOS Build 17(2026-08-03提出時点)の圧縮ファイルサイズ31.3MBとの比較が
依頼にあったが、Build 17はオンボーディングスライド機能(PR #51、
2026-08-05マージ)を含んでいない時点のビルドである。オンボーディング
画像は`pubspec.yaml`の`assets:`宣言によりiOS/Android共通で同梱される
ため、iOS側でも次回ビルド(1.0.0+19以降)でおおむね同量(圧縮後
25〜30MB程度)のサイズ増加が見込まれる。iOS(IPA)とAndroid(AAB)は
アーカイブ形式・圧縮方式が異なるため単純な数値比較はあくまで目安だが、
「オンボーディング画像追加が両OS共通の主要因である」という結論は
iOS側にも同様に当てはまる。iOS側の画像圧縮(A/B相当)も同時に検討する
価値がある。

## 内訳算出スクリプト(参考)

```python
import zipfile, collections

aab_path = "build/app/outputs/bundle/release/app-release.aab"
zf = zipfile.ZipFile(aab_path)
infos = zf.infolist()

# ディレクトリ単位で compress_size を集計
buckets = collections.Counter()
for i in infos:
    parts = i.filename.split('/')
    key = '/'.join(parts[:2]) if len(parts) > 1 else parts[0]
    buckets[key] += i.compress_size

for k, v in buckets.most_common(20):
    print(f"{v/1024/1024:8.2f} MiB  {k}")
```

対象ファイル: `build/app/outputs/bundle/release/app-release.aab`
(2026-08-06 12:04生成、Build 18相当、93,704,993 bytes)
