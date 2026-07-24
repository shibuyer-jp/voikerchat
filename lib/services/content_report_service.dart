import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ContentReportService: AI生成コンテンツの報告(Google Play ポリシー必須要件)。
///
/// content_reports への直接INSERT。RLSが auth.uid() = user_id を強制するため、
/// クライアントが他人になりすまして報告することはDB側で拒否される。
/// 監査ログのため update/delete のメソッドは提供しない(RLSでも全面禁止)。
class ContentReportService {
  final logger = Logger('ContentReportService');

  final SupabaseClient _supabase;

  ContentReportService(this._supabase);

  static ContentReportService? _instance;

  static ContentReportService getInstance(SupabaseClient supabase) {
    _instance ??= ContentReportService(supabase);
    return _instance!;
  }

  /// AI応答を報告する。
  ///
  /// [reason] は 'inappropriate' | 'incorrect' | 'other' のいずれか。
  /// 成功時 true、失敗時 false を返す(呼び出し元でエラー表示を判断する)。
  Future<bool> submitReport({
    required String userId,
    required String reason,
    String? messageId,
    String? sceneId,
    String? detail,
    String? reportedText,
  }) async {
    try {
      await _supabase.from('content_reports').insert({
        'user_id': userId,
        'message_id': messageId,
        'scene_id': sceneId,
        'reason': reason,
        'detail': detail,
        'reported_text': reportedText,
      });
      logger.info('[ContentReport] Report submitted (reason: $reason)');
      return true;
    } on PostgrestException catch (e) {
      logger.warning('[ContentReport] Failed to submit report: ${e.message}');
      return false;
    }
  }
}
