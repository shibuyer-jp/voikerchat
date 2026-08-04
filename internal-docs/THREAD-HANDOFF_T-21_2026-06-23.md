# Voikerchat T-21 Notification System - スレッド引き継ぎドキュメント
**作成日：2026-06-23**  
**ステータス：Phase 1-2 完成、Phase 3 開始準備**

---

## 現在までの完了状況

### ✅ T-21 Phase 1: LocalNotificationService
**コミット：** `e235539`  
**実装行数：** 543行

- LocalNotificationService クラス（257行）
  - `initialize()` - iOS/Android初期化
  - `showNotification()` - 即座通知
  - `scheduleNotification()` - 定時通知
  - `scheduleDailyNotification()` - 毎日定時通知（繰り返し）
  - `cancelNotification()` / `cancelAllNotifications()`

- NotificationScheduler クラス（207行）
  - Daily Reminder（8h/12h/19h JST）
  - Milestone（3d/7d/14d/30d）
  - Premium Upsell（Stage 1/2/3）
  - Feature Update

- NotificationIds 定数（11種類）
- ユニットテスト（77行）

**パッケージ追加：**
- `flutter_local_notifications: ^17.1.0`
- `timezone: ^0.9.0`

---

### ✅ T-21 Phase 2: RemoteNotificationService + Firebase
**コミット：** `7967d79`  
**実装行数：** 734行

- RemoteNotificationService クラス（261行）
  - Firebase 初期化
  - FCM トークン管理（取得/リフレッシュ/削除）
  - メッセージハンドラー設定
  - フォアグラウンド/バックグラウンド/終了状態対応
  - トピック購読（all_users, premium_users, japanese_learners等）
  - APNs トークン取得（iOS）

- NotificationDataModel クラス（125行）
  - Firebase → モデル変換
  - JSON 往復変換
  - Immutable update（copyWith）
  - NotificationTypes 定数（4種類）

- テスト（160行）
  - JSON シリアライズ
  - Firebase マップ変換
  - 等値性比較

- Firebase FCM セットアップガイド（186行）
  - Android/iOS 設定手順
  - バックエンド連携例
  - トラブルシューティング

**パッケージ追加：**
- `firebase_core: ^2.24.0`
- `firebase_messaging: ^14.7.0`
- `mockito: ^5.4.0`（dev）

---

### ✅ エラー修正
**コミット：** `bdff00c` → `8925725`

1. **API 互換性修正**（bdff00c）
   - `DarwinInitializationSettings` → `defaultPresentationOptions` 削除
   - `TZDateTime` → `tz.TZDateTime` 型修正
   - `zonedSchedule` → `androidScheduleMode` パラメータ削除
   - mockito 削除（テスト簡略化）

2. **型エラー修正**（8925725）
   - `customData` → `Map<String, String>` の null 値代入エラー修正
   - `fromFirebaseMap()` → null 安全化

**現在：すべてのテスト合格 ✅**

---

## 次タスク：T-21 Phase 3

### 概要
ChatScreen と NotificationScheduler を統合し、以下を実装：
- 通知受信時の UI 更新（ストリーク表示、スコア更新）
- 通知ペイロード処理
- 通知タップでのディープリンク処理

### 工数
- **3A: ChatScreen 統合** ～4h
  - ChatScreen での通知リスナー設定
  - ストリーク / スコア UI リアルタイム更新
  - 通知ペイロードに基づくシーン遷移

- **3B: NotificationHistory 画面** ～3.5h
  - 通知履歴表示画面
  - 既読 / 未読 状態管理
  - 通知フィルタリング（種別別）

- **3C: 両方実装** ～7.5h

---

## アーキテクチャ全体図

```
┌─────────────────────────────────────────────────────────┐
│                    Firebase Cloud                        │
│              (Remote Notification Server)                │
└──────────────────────┬──────────────────────────────────┘
                       │ FCM Message
                       ▼
         ┌─────────────────────────────┐
         │ RemoteNotificationService   │
         │  - FCM トークン管理          │
         │  - メッセージハンドラー      │
         │  - トピック購読              │
         └────────┬────────────────────┘
                  │
        ┌─────────┴──────────┐
        ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│ LocalNotification │  │ NotificationData │
│   Service        │  │     Model        │
│ (iOS/Android)    │  │ (JSON serialized)│
└────────┬─────────┘  └──────────────────┘
         │
         ▼
┌──────────────────────────┐
│  NotificationScheduler   │
│  - Daily Reminder        │
│  - Milestone             │
│  - Premium Upsell        │
│  - Feature Update        │
└────────┬─────────────────┘
         │
         ▼
    ┌─────────────────────────────┐
    │ ChatScreen / UI Components  │
    │ - ストリーク表示            │
    │ - スコア更新                │
    │ - 通知ペイロード処理        │
    └─────────────────────────────┘
```

---

## 次スレッド開始チェックリスト

- [ ] メモリ番号 #30 を確認
- [ ] GitHub リポジトリ最新コミット: `8925725`
- [ ] Phase 3 開始前に `flutter pub get` で依存関係更新
- [ ] `flutter test` で全テスト合格確認
- [ ] Phase 3A / 3B / 3C いずれかを選択
- [ ] このドキュメント（THREAD-HANDOFF_T-21_2026-06-23.md）を GitHub に保存

---

## 参考リンク

- **GitHub リポジトリ：** https://github.com/shibuyer-jp/voikerchat
- **T-21 仕様ドキュメント：** `docs/T-21-Notification-System-v1.0.md`
- **Firebase セットアップガイド：** `docs/Firebase-FCM-Setup-Guide.md`
- **Persona 定義：** `docs/Persona-Design-v1.0.md`

---

## 問題発生時の対応

| 問題 | 原因 | 対応 |
|------|------|------|
| テスト失敗 | 依存パッケージ未更新 | `flutter pub get` 実行 |
| Firebase エラー | google-services.json 未配置 | `android/app/google-services.json` 確認 |
| 通知表示されない | setMessageHandler 未呼び出し | RemoteNotificationService 初期化後に設定 |

---

**準備完了。次スレッドでお待ちしています！** 🚀
