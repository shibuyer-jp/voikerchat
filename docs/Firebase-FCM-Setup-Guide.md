# Firebase Cloud Messaging (FCM) セットアップガイド

## 概要
Voikerchat は Firebase Cloud Messaging を使用してリモート通知（プッシュ通知）を管理します。

## 前提条件
- Firebase プロジェクト（Google Cloud Console で作成済み）
- iOS: Apple Developer アカウント（APNs証明書）
- Android: Google Play アカウント

## Android セットアップ

### 1. google-services.json の配置
```
android/app/google-services.json
```
Firebase Console からダウンロードした `google-services.json` を上記パスに配置。

### 2. android/build.gradle の更新
```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
  }
}
```

### 3. android/app/build.gradle の更新
```gradle
// 末尾に追加
apply plugin: 'com.google.gms.google-services'
```

### 4. Android Manifest 権限
`android/app/src/main/AndroidManifest.xml` に以下を追加：
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## iOS セットアップ

### 1. GoogleService-Info.plist の配置
```
ios/Runner/GoogleService-Info.plist
```
Firebase Console からダウンロードした `GoogleService-Info.plist` を Xcode で Runner プロジェクトに追加。

### 2. APNs 証明書の設定
1. Apple Developer アカウントで Key Identifier を作成
2. Firebase Console → Project Settings → Cloud Messaging → APNs Key を設定
3. .p8 ファイルをアップロード

### 3. Podfile 更新
```ruby
# Pod dependencies
pod 'Firebase/Core'
pod 'Firebase/Messaging'

# 実行
cd ios && pod install && cd ..
```

### 4. iOS デプロイメント設定
- Minimum iOS Deployment Target: 12.0 以上
- Xcode: Signing & Capabilities で "Push Notifications" を有効化

## Dart/Flutter 統体化

### 初期化コード（main.dart）
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // 自動生成ファイル

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // RemoteNotificationService 初期化
  final remoteService = RemoteNotificationService();
  await remoteService.initialize(
    localNotificationService: localNotificationService,
    firebaseInitialized: true,
  );
  
  runApp(const VoikerchatApp());
}
```

### FlutterFire CLI（推奨）
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
このコマンドで自動的に `lib/firebase_options.dart` が生成されます。

## バックエンド連携

### FCM トークン送信
ユーザーログイン時に FCM トークンをバックエンドに送信：
```dart
final token = await RemoteNotificationService().getFCMToken();
// バックエンド API に POST: /api/fcm-token
```

### リモート通知の送信（バックエンド例：Node.js/Express）
```javascript
const admin = require('firebase-admin');

admin.messaging().send({
  notification: {
    title: '朝の学習時間',
    body: 'Voikerchatで日本語を学習しましょう！',
  },
  data: {
    notification_id: 'reminder_2026_06_23',
    notification_type: 'daily_reminder',
    title: '朝の学習時間',
    body: 'Voikerchatで日本語を学習しましょう！',
  },
  token: userFCMToken,
});
```

## トピック管理

### 推奨トピック
- `all_users`: すべてのユーザー
- `premium_users`: プレミアムユーザー（条件付き購読）
- `japanese_learners`: 日本語学習者
- `new_features`: 新機能リリース
- `bug_fixes`: バグ修正通知

### 購読コード
```dart
await remoteService.subscribeToTopic('all_users');
await remoteService.subscribeToTopic('japanese_learners');
```

## テスト手順

### 1. ローカルテスト
```bash
flutter run
```

### 2. Firebase Console でテスト送信
Firebase Console → Messaging → Create campaign → Send Test Message

### 3. FCM トークン確認
```dart
final token = await RemoteNotificationService().getFCMToken();
print('FCM Token: $token');
```

## トラブルシューティング

| 問題 | 原因 | 解決策 |
|------|------|--------|
| トークン取得失敗 | Firebase 未初期化 | `Firebase.initializeApp()` を先に実行 |
| 通知表示されない (フォアグラウンド) | `onMessage` リスナー未設定 | `setMessageHandler()` を呼び出す |
| APNs エラー (iOS) | 証明書期限切れ | Apple Developer で新規キーを生成 |
| gradle ビルド失敗 | google-services.json 未配置 | パスを確認: `android/app/google-services.json` |

## セキュリティ考慮事項

1. **FCM トークンの管理**
   - ログアウト時に `deleteFCMToken()` を呼び出し
   - トークンをローカルストレージに保存（SharedPreferences）

2. **データ暗号化**
   - Firebase ルールで認証済みユーザーのみアクセス許可
   - 通知ペイロードに機密情報を含めない

3. **レート制限**
   - ユーザーごとの通知頻度制限（バックエンド実装）
   - 1ユーザーあたり 1日最大 5通など

## リファレンス
- [Firebase Cloud Messaging ドキュメント](https://firebase.flutter.dev/docs/messaging/overview)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli)
- [Firebase Android セットアップ](https://firebase.google.com/docs/android/setup)
- [Firebase iOS セットアップ](https://firebase.google.com/docs/ios/setup)
