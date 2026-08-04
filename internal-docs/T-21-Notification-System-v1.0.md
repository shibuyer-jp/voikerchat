# T-21 Notification System v1.0

**Date**: 2026-06-23  
**Task**: T-21 Notification System  
**Status**: Specification Phase  
**Scope**: Local notifications, push notifications, smart scheduling  

---

## 目的

ユーザーの学習継続を促進するための通知システムを構築。Premium/Free 両者に対応した段階的な通知戦略を実装。

---

## 通知の種類（4カテゴリ）

### 1. 学習リマインダー（Daily）

**対象**: Free & Premium 両者  
**トリガー**: 毎日指定時刻（デフォルト: 朝8時、昼12時、夜19時）  
**メッセージ例**:
- 朝: 「おはよう！今日も学習しませんか？」
- 昼: 「今日はまだ1回だけ。連続記録を保ちましょう」
- 夜: 「1日の学習を完了しましたか？」

**UI**: Local Notification（バナー）  
**Action**: タップで ChatScreen へ遷移  

---

### 2. ストリーク達成通知（Milestone）

**対象**: Free & Premium 両者  
**トリガー**: 3日, 7日, 14日, 30日連続達成時  
**メッセージ例**:
- 3日: 「🔥 3日連続達成！」
- 7日: 「🎉 1週間連続！Premium にアップグレードして継続しましょう」
- 30日: 「🏆 1ヶ月達成！あなたは日本語マスターへの道を歩んでいます」

**UI**: Rich Notification（画像 + テキスト）  
**Action**: タップで StatsScreen へ遷移  

---

### 3. Premium勧導通知（Conversion）

**対象**: Free ユーザーのみ  
**トリガー**: T-20 で定義した Premium UpsellService と連携
- Stage 1: Day 1, 5回以上会話後
- Stage 2: Day 3, 連続使用時
- Stage 3: Day 7, ストリーク達成時

**メッセージ例**:
- 「無制限学習へ: Premium なら1日制限なし」
- 「アニメシーン解放: 友情・感動・ギャグシーン」

**UI**: Local Notification（アクション付き）  
**Action**: 「詳細」→ PremiumScreen / 「登録」→ RevenueCat IAP  

---

### 4. 新機能通知（Feature Updates）

**対象**: All users（管理画面から配信）  
**トリガー**: 新シーン追加時、アップデート時
**メッセージ例**:
- 「新シーン追加: 『居酒屋』で敬語マスター」
- 「v1.1 アップデート: 新しい分析ダッシュボード」

**UI**: In-app Banner + Local Notification  
**Action**: タップで新機能へ誘導  

---

## 技術スタック

### パッケージ
- `flutter_local_notifications` (0.9.0+)
- `timezone` (0.9.0+)
- `firebase_messaging` (14.0.0+) ※ Push通知用、Phase 2で追加

### Platform-specific
- **iOS**: UserNotifications framework (local) + APNs (push)
- **Android**: NotificationCompat (local) + FCM (push)

### Backend Integration
- Supabase: notification_preferences テーブル
- Firebase Cloud Messaging (Phase 2)

---

## 実装スケジュール（優先度順）

| # | 機能 | 難度 | 工数 | 優先度 |
|---|------|------|------|--------|
| 1 | LocalNotificationService | ⭐⭐ | 3h | ⭐⭐⭐ |
| 2 | Daily reminder scheduling | ⭐⭐ | 2.5h | ⭐⭐⭐ |
| 3 | Milestone notifications | ⭐ | 1.5h | ⭐⭐⭐ |
| 4 | Premium upsell integration | ⭐ | 1h | ⭐⭐ |
| 5 | Notification preferences UI | ⭐⭐ | 2h | ⭐⭐ |
| 6 | Analytics & tracking | ⭐ | 1h | ⭐ |

**合計工数**: 10.5h（1.5日）

---

## Database Schema（Supabase）

### `notification_preferences` テーブル

```sql
CREATE TABLE notification_preferences (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  
  -- Daily reminder settings
  enable_daily_reminders BOOLEAN DEFAULT true,
  reminder_times TEXT[] DEFAULT ARRAY['08:00', '12:00', '19:00'],
  reminder_timezone VARCHAR DEFAULT 'Asia/Tokyo',
  
  -- Milestone notifications
  enable_milestone_notifications BOOLEAN DEFAULT true,
  milestone_days INT[] DEFAULT ARRAY[3, 7, 14, 30],
  
  -- Premium upsell
  enable_upsell_notifications BOOLEAN DEFAULT true,
  
  -- Feature updates
  enable_feature_notifications BOOLEAN DEFAULT true,
  
  -- Quiet hours
  quiet_hours_enabled BOOLEAN DEFAULT false,
  quiet_hours_start VARCHAR,
  quiet_hours_end VARCHAR,
  
  -- Last notification times
  last_daily_reminder_date DATE,
  last_milestone_notification_date DATE,
  last_upsell_notification_date DATE,
  
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- RLS Policy: Users can only read/update their own preferences
CREATE POLICY "Users can manage own preferences"
  ON notification_preferences
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

---

## Data Model（Dart）

```dart
class NotificationPreference {
  final String id;
  final String userId;
  final bool enableDailyReminders;
  final List<String> reminderTimes;  // HH:mm format
  final String reminderTimezone;
  final bool enableMilestoneNotifications;
  final List<int> milestoneDays;
  final bool enableUpsellNotifications;
  final bool enableFeatureNotifications;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  // ... timestamps
}

class NotificationPayload {
  final String id;
  final String type;  // 'reminder', 'milestone', 'upsell', 'feature'
  final String title;
  final String body;
  final Map<String, dynamic> data;  // Action routing
  final DateTime scheduledAt;
}
```

---

## 通知フロー（シーケンス図）

```
Day 1
├─ 08:00: Daily reminder (toast)
├─ 12:00: Daily reminder (toast)
├─ 19:00: Daily reminder (toast)
└─ After 5+ conversations: Premium upsell Stage 1 (toast)

Day 3
├─ Daily reminders (3x toast)
└─ If continuous: Premium upsell Stage 2 (dialog) + Milestone 3-day (notification)

Day 7
├─ Daily reminders (3x toast)
└─ If continuous: Premium upsell Stage 3 (banner) + Milestone 7-day (notification)

Day 30
├─ Daily reminders (3x toast)
└─ If continuous: Milestone 30-day (rich notification)
```

---

## UI/UX 仕様

### Notification Preferences Screen

```
Settings > Notifications
├─ Daily Reminders
│  ├─ [Toggle] Enable daily reminders
│  ├─ Time 1: 08:00 [Edit]
│  ├─ Time 2: 12:00 [Edit]
│  ├─ Time 3: 19:00 [Edit]
│  └─ Timezone: Asia/Tokyo [Dropdown]
├─ Milestones
│  ├─ [Toggle] Enable milestone notifications
│  ├─ [Checkbox] 3-day streak
│  ├─ [Checkbox] 7-day streak
│  ├─ [Checkbox] 14-day streak
│  └─ [Checkbox] 30-day streak
├─ Premium Offers
│  └─ [Toggle] Show Premium upsell notifications
├─ Feature Updates
│  └─ [Toggle] Show feature update notifications
└─ Quiet Hours
   ├─ [Toggle] Enable quiet hours
   ├─ Start: 23:00 [Edit]
   └─ End: 08:00 [Edit]
```

---

## テスト戦略

### Unit Tests
- NotificationScheduler: scheduling logic
- NotificationPreference: validation
- Timezone conversion

### Widget Tests
- NotificationPreferencesScreen rendering
- Toggle state changes

### E2E Tests (Integration)
- Schedule notification → verify delivery
- User interaction → verify routing
- Quiet hours → verify suppression

### Manual Testing
- All 4 notification types on device
- Platform-specific (iOS/Android)
- Deep link routing from notifications

---

## スコープ外（T-22+）

🚫 Push notifications (Firebase) → T-22  
🚫 Rich media notifications (images) → T-22  
🚫 Notification analytics dashboard → T-23  
🚫 User feedback (snooze, mark as read) → T-24  

---

## 成功指標

| KPI | 目標 | 測定方法 |
|-----|------|--------|
| **Daily Reminder CTR** | > 15% | Tap count / total delivered |
| **Milestone Engagement** | > 25% | Screen view post-notification |
| **Premium Conv (Upsell)** | > 8% | IAP subscriptions / upsell shown |
| **Opt-out Rate** | < 10% | Users disabling notifications |

---

**作成者**: Claude  
**最終更新**: 2026-06-23  
**次ステップ**: GitHub push → T-21 Phase 1 実装開始
