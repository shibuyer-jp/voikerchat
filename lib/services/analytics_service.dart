import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/platform_code.dart';
import 'locale_service.dart';

/// usage_logs.event のうち AnalyticsService が使う値。
/// usage_logs_event_check は既にこれらを含む8値を許可済みのため、
/// 新規イベントを追加する場合もマイグレーションは発生しない。
abstract final class AnalyticsEvent {
  static const sessionStart = 'session_start';
  static const upsellShown = 'upsell_shown';
  static const upsellClicked = 'upsell_clicked';
  static const upsellConverted = 'upsell_converted';
}

/// AnalyticsService: usage_logsへのアップセルファネル計測用ロガー。
///
/// fire-and-forget(呼び出し元はawaitしない・例外は一切外へ伝播しない)。
/// 分析ログの失敗がユーザー体験を止めてはならないため、insert失敗は
/// debugPrintのみで握りつぶす(ContentReportServiceのRLS前提insertと同じ
/// 方針だが、あちらは失敗をUIへ伝える必要があるためbool返却、こちらは
/// 分析専用のため呼び出し元へは一切返さない)。
///
/// scene_id列へは書き込まない(usage_logs_scene_id_checkが1..13のままで
/// 実装のシーン数18と不一致のため)。シーンを記録したい場合は
/// metadata['scene']へ文字列で入れる(api/chat.tsと同方針)。
class AnalyticsService {
  /// [insertRow]/[currentUserId] はテスト用の差し替え口(既定は本物の
  /// SupabaseClientを使う)。SupabaseClientの`.from().insert()`は
  /// `PostgrestFilterBuilder<T>`という具象クラスを返すためモックしづらく、
  /// insert呼び出しと認証済みuser_id解決を関数として切り出すことで
  /// SupabaseClient自体のモックを不要にしている。
  AnalyticsService(
    SupabaseClient supabase, {
    Future<void> Function(Map<String, dynamic> row)? insertRow,
    String? Function()? currentUserId,
  })  : _insertRow = insertRow ?? ((row) => supabase.from('usage_logs').insert(row)),
        _currentUserId = currentUserId ?? (() => supabase.auth.currentUser?.id);

  final Future<void> Function(Map<String, dynamic> row) _insertRow;
  final String? Function() _currentUserId;

  static AnalyticsService? _instance;

  static AnalyticsService getInstance(SupabaseClient supabase) {
    _instance ??= AnalyticsService(supabase);
    return _instance!;
  }

  /// テスト間でシングルトンを持ち越さないためのリセット(getInstance()を
  /// 使うテストでのみ必要。差し替え口経由で直接AnalyticsService(...)を
  /// 生成するテストには不要)。
  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance = null;
  }

  /// usage_logsへイベントを記録する(fire-and-forget)。
  void logEvent({
    required String event,
    String? sessionId,
    required bool isPremium,
    Map<String, dynamic>? metadata,
  }) {
    unawaited(_insert(
      event: event,
      sessionId: sessionId,
      isPremium: isPremium,
      metadata: metadata,
    ));
  }

  Future<void> _insert({
    required String event,
    String? sessionId,
    required bool isPremium,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _currentUserId();
      if (userId == null) {
        debugPrint('[AnalyticsService] logEvent($event) skipped: no authenticated user');
        return;
      }

      await _insertRow({
        'user_id': userId,
        'event': event,
        'session_id': sessionId,
        'platform': currentPlatformCode(),
        'locale': LocaleService.resolveLocaleCodeForLogging(),
        'is_premium': isPremium,
        'metadata': metadata ?? <String, dynamic>{},
      });
    } catch (e) {
      debugPrint('[AnalyticsService] logEvent($event) failed: $e');
    }
  }
}
