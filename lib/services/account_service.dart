import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アカウント削除を担うサービス。
///
/// サーバ側 `/api/delete-account` を呼び出して本人のアカウントと
/// 全学習データを完全削除し、成功後にローカル状態を初期化する。
///
/// App Store / Google Play が要求する「アプリ内アカウント削除」を満たす。
class AccountService {
  AccountService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://voikerchat.com';

  // main.dart の RootScreen が参照するオンボーディング判定キー。
  // 削除後はこれらを消し、次回は新規ユーザーとしてオンボーディングから開始させる。
  static const String _kFirstLaunchKey = 'is_first_launch';
  static const String _kUserLevelKey = 'user_diagnostic_level';

  // 施策③で追加したオンボーディング関連フラグ(learner_preferences_service.dart
  // と同一のキー文字列)。消し忘れると、削除後の新規ユーザーなのに
  // スライド既読/テスト受験済み扱いになってしまう。
  static const String _kOnboardingSlidesCompletedKey =
      'onboarding_slides_completed';
  static const String _kDiagnosticTestCompletedKey =
      'diagnostic_test_completed';
  static const String _kLevelTestCardDismissedDateKey =
      'level_test_card_dismissed_date';

  /// 本人のアカウントを完全削除する。
  ///
  /// 成功時: サーバ側でデータ削除 → ローカルセッション破棄 → ローカル状態初期化
  /// → 新しい匿名ユーザーを作成し、アプリが継続動作できる状態にする。
  ///
  /// 失敗時: [Exception] を送出する（呼び出し側で握って UI 表示する想定）。
  Future<void> deleteAccount() async {
    final auth = Supabase.instance.client.auth;
    final token = auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No active session');
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/delete-account'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode != 200) {
      String message = 'Delete failed: ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          message = decoded['error'].toString();
        }
      } catch (_) {
        // ボディが JSON でない場合はステータスコードのメッセージを使う。
      }
      throw Exception(message);
    }

    // 成功: ローカル状態を初期化する。
    await _resetLocalState(auth);
  }

  Future<void> _resetLocalState(GoTrueClient auth) async {
    // 1. 削除済みユーザーのローカルセッションを破棄。
    try {
      await auth.signOut();
    } catch (_) {
      // セッションが既に無効でも問題ない。
    }

    // 2. オンボーディング完了フラグ等をクリア（次回起動でオンボーディングを再表示）。
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFirstLaunchKey);
      await prefs.remove(_kUserLevelKey);
      await prefs.remove(_kOnboardingSlidesCompletedKey);
      await prefs.remove(_kDiagnosticTestCompletedKey);
      await prefs.remove(_kLevelTestCardDismissedDateKey);
    } catch (_) {
      // ローカル設定の消去に失敗してもアカウント削除自体は成功している。
    }

    // 3. 新しい匿名ユーザーを作成し、アプリを継続動作可能な状態にする。
    //    （失敗しても次回起動時に main() が匿名サインインを行うため致命的でない）
    try {
      await auth.signInAnonymously();
    } catch (_) {
      // 次回起動時に回復する。
    }
  }
}
