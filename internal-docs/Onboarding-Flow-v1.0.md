# Voikerchat オンボーディングフロー詳細設計 v1.0

**作成日**: 2026-06-19  
**バージョン**: v1.0  
**ステータス**: 確定  
**対象**: iOS/Android ネイティブアプリ（Flutter）

---

## 概要

ユーザーがアプリを初めて起動してから、最初のチャットセッションを開始するまでの完全フロー。5ステップ + 言語選択で構成。

### 設計方針
- **最小化**: 5～10分で完了
- **学習価値**: 診断テスト実施 → パーソナライズド推奨
- **柔軟性**: スキップ・後からの変更に対応
- **技術**: API統合、ローカルストレージ、エラーハンドリング含む

---

## 全体フロー図

```
アプリ起動
    ↓
[IS_FIRST_LAUNCH チェック]
    ↓
YES → Step 0: 言語選択
    ↓
Step 1: ウェルカム画面
    ↓
Step 2: 基本操作説明
    ↓
Step 3: 診断テスト
    ├─ スキップ → Step 4へ
    └─ 完了 → Step 4へ
    ↓
Step 4: レベル結果
    ├─ 広告再挑戦（0点のみ）
    └─ 続行 → Step 5へ
    ↓
Step 5: シーン選択
    ├─ シーン開始 → チャットセッション開始
    └─ 後で選ぶ → メインアプリトップ
    ↓
メインアプリ
```

NO（既存ユーザー）→ メインアプリ直接起動

---

## Step 0: 言語選択（新規）

### UI仕様

| 項目 | 仕様 |
|------|------|
| **背景** | 濃紺（#1A3A70） |
| **タイトル** | "Select Your Language" / "言語を選択してください" / "Pumili ng Wika" |
| **選択肢** | 日本語 / English / Tagalog |
| **ボタン** | 「次へ」（各言語テキスト対応） |
| **アニメーション** | フェードイン（全体） |

### 技術仕様

```
API POST: /api/user/init
Request:
{
  "device_id": "UUID",
  "app_version": "1.0.0",
  "language": "ja" | "en" | "tl"
}

Response:
{
  "user_id": "uuid",
  "session_token": "jwt_token",
  "language": "ja",
  "created_at": "2026-06-19T12:00:00Z"
}
```

### ローカルストレージ

```
SharedPreferences (Dart):
- user_id: String
- session_token: String
- selected_language: String (ja/en/tl)
- is_first_launch: bool → false に更新
- onboarding_step: int = 1
```

---

## Step 1: ウェルカム画面

| 項目 | 仕様 |
|------|------|
| **背景** | フィリピン青（#0047AB）→ 日本赤（#DC143C）グラデーション |
| **メインテキスト** | 「フィリピン人の婚約者と日本語で話そう」（24px、丸ゴシック） |
| **ボタン** | 「始める」（#FFD700、幅100px、高さ48px） |
| **アニメーション** | ロゴフェードイン + テキスト1文字ずつ出現 |

### バックボタン動作
- 表示なし（最初のステップ）

### スキップ機能
- なし

---

## Step 2: 基本操作説明

### UI要素（5つ）と説明

| # | UI要素 | 説明テキスト |
|----|--------|------------|
| 1️⃣ | **🎚️ レベル選択** | 「初心者・中級者・上級者から選んでください。いつでも変更できます。」 |
| 2️⃣ | **📋 シーン選択** | 「『友達とカフェ』『レストランで注文』など13のシーンから選択。」 |
| 3️⃣ | **💬 チャット入力** | 「日本語を入力またはマイクで話しかけると、キャラが返答します。」 |
| 4️⃣ | **⚙️ 設定** | 「音声ON/OFF、言語切替（日本語・英語・タガログ）などはここで設定。」 |
| 5️⃣ | **👤 プロフィール** | 「あなたの学習進捗、バッジ、使用回数をここで確認できます。」 |

### バックボタン動作
- Step 0（言語選択）に戻る

### スキップ機能
- 「スキップ」ボタン → Step 3へ直接遷移

---

## Step 3: 診断テスト

### テスト仕様

| 項目 | 仕様 |
|------|------|
| **問数** | 3問固定 |
| **難度段階** | Q1: N4（初級）/ Q2: N3（中級）/ Q3: N2（中上級） |
| **形式** | 4択 + 「わかりません」（5番目の選択肢） |
| **タイマー** | なし（時間制限なし） |
| **スコア計算** | 正解 = 1点、わかりません/スキップ = 0点 |
| **判定** | 3点→Advanced / 1-2点→Intermediate / 0点→Beginner |

### API連携

```
API POST: /api/onboarding/test/submit
Request:
{
  "user_id": "uuid",
  "answers": [
    { "question_id": 1, "answer": "A" },
    { "question_id": 2, "answer": "skip" },
    { "question_id": 3, "answer": "B" }
  ]
}

Response:
{
  "score": 2,
  "level": "Intermediate",
  "recommended_scenes": ["restaurant", "shopping"]
}
```

### バックボタン動作
- 「戻る」確認ダイアログ表示 → 「本当に戻りますか？進捗は失われます」
- YES → Step 2に戻る（スコア破棄）

### スキップ機能
- 各問にてスキップ可
- 全スキップ → 0点 → Step 4へ

---

## Step 4: レベル結果

### レベル判定と表示

| スコア | レベル | テキスト | 背景色 |
|--------|--------|----------|--------|
| 3点 | Advanced | 「あなたは上級者です！」 | 濃青#1A3A70 |
| 1-2点 | Intermediate | 「あなたは中級者です」 | 紫#6B4BA3 |
| 0点 | Beginner | 「初心者からスタートしよう」 | 薄青#4A90E2 |

### アニメーション
- スコア表示: カウントアップ（0 → 最終スコア）
- バッジ表示: フェードイン（遅延0.5s）

### 広告オプション（0点のみ）
- 「広告を見てもう一度挑戦する」ボタン表示
- AdMob動画再生 → 再度 Step 3へ
- キャンセル → Beginner確定 → Step 5へ

### ローカルストレージ更新

```
SharedPreferences:
- user_level: "Beginner" | "Intermediate" | "Advanced"
- diagnostic_score: int
- onboarding_step: int = 5
```

### API連携

```
API POST: /api/user/level/update
Request:
{
  "user_id": "uuid",
  "level": "Intermediate",
  "score": 2
}

Response:
{
  "success": true,
  "updated_at": "2026-06-19T12:05:00Z"
}
```

### バックボタン動作
- Step 3に戻る（再度テスト可能）

---

## Step 5: シーン選択

### シーン一覧（13シーン）

| # | シーン名 | 推奨レベル | アイコン |
|----|---------|----------|---------|
| 1 | 友達とカフェ | Beginner | ☕ |
| 2 | レストランで注文 | Intermediate | 🍽️ |
| 3 | 買い物 | Intermediate | 🛍️ |
| 4 | 電車で移動 | Intermediate | 🚋 |
| 5 | 病院 | Intermediate | 🏥 |
| 6 | 自己紹介 | Advanced | 🎌 |
| 7 | カフェでゆったり | Beginner | ☕ |
| 8 | フリートーク | Any | 💬 |
| 9 | 熱血戦闘シーン | Intermediate | ⚡ |
| 10 | 友情協力シーン | Beginner | 🤝 |
| 11 | 感動涙シーン | Intermediate | 😢 |
| 12 | 日常学園シーン | Intermediate | 📚 |
| 13 | ギャグ会話 | Any | 😂 |

### UI動作
- **推奨シーン表示**: レベル判定後、推奨シーンを最上位に表示 + グロー効果
- **ボタン**: 「シーン開始」→チャット開始 / 「後で選ぶ」→メインアプリトップ

### API連携

```
API POST: /api/onboarding/scene/select
Request:
{
  "user_id": "uuid",
  "scene_id": 1
}

Response:
{
  "session_id": "uuid",
  "scene": {
    "id": 1,
    "name": "友達とカフェ",
    "persona_id": "barista_001",
    "level": "Beginner"
  },
  "first_message": "いらっしゃいませ！何をお飲みになりますか？"
}
```

### ローカルストレージ更新

```
SharedPreferences:
- is_first_launch: false
- onboarding_complete: true
- last_scene_id: int
- default_level: "Intermediate"
```

### バックボタン動作
- Step 4に戻る

---

## エラーハンドリング

### ネットワークエラー

```
Scenario: Step 0 で API呼び出し失敗
- ダイアログ表示: 「インターネット接続を確認してください」
- Retry ボタン → API再呼び出し
- Cancel → アプリ終了または Step 0 保持
```

### タイムアウト

```
タイムアウト時間: 30秒
- リトライ表示 → 最大3回まで
- 3回失敗 → エラーメッセージ + ローカル保存（オフライン対応）
```

### 無効なレスポンス

```
API レスポンスが不正な場合:
- ログ記録 → デフォルト値を使用（level: "Beginner"）
- ユーザーに警告なし（シームレス処理）
```

---

## データモデル

### User（オンボーディング関連）

```dart
class User {
  String id;
  String deviceId;
  String language; // ja, en, tl
  String level; // Beginner, Intermediate, Advanced
  int diagnosticScore;
  DateTime createdAt;
  DateTime completedOnboardingAt;
  bool isFirstLaunch;
}
```

### OnboardingState

```dart
class OnboardingState {
  int currentStep; // 0-5
  int? diagnosticScore;
  String? selectedLanguage;
  String? selectedLevel;
  int? selectedSceneId;
  List<dynamic> testAnswers;
}
```

---

## 実装チェックリスト

- [ ] Step 0 UI実装（言語選択）
- [ ] API統合（/api/user/init）
- [ ] SharedPreferences ローカルストレージ管理
- [ ] Step 1-5 UI実装（既存Tutorial-Design-v1.0参照）
- [ ] 診断テスト API（/api/onboarding/test/submit）
- [ ] レベル更新 API（/api/user/level/update）
- [ ] シーン選択 API（/api/onboarding/scene/select）
- [ ] エラーハンドリング（ネットワーク、タイムアウト）
- [ ] バックボタン動作テスト
- [ ] スキップ機能テスト
- [ ] 言語切替テスト（ja, en, tl）
- [ ] オフラインモード対応テスト

---

## 次のステップ

1. **Flutter UI実装**: 各ステップの Flutter Widget作成
2. **API統合**: Backend との連携テスト
3. **ローカルストレージ**: SharedPreferences 管理の確認
4. **QA**: 全フロー通してのテスト（言語別）
