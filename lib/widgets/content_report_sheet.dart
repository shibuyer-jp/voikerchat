import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/content_report_service.dart';
import '../theme/app_colors.dart';

/// ContentReportSheet: AI応答を報告するボトムシート。
///
/// Google Play デベロッパープログラムポリシー(AIでコンテンツを生成する
/// アプリは、ユーザーがアプリを離れずに不適切なコンテンツを報告できる
/// アプリ内機能を備える必要がある)への対応。
///
/// 理由(不適切な内容/誤った情報/その他)を選択し、任意の自由記述を添えて
/// content_reports テーブルへ送信する。送信成功時は `true` を返して pop する
/// (確認トーストは呼び出し元の ChatScreen が表示する)。
///
/// Supabase クライアントへのアクセスは送信時(_submit)まで遅延させる。
/// State構築時に触れると、Supabase未初期化の環境(ウィジェットテスト等)で
/// 即座にAssertionErrorとなるため。
class ContentReportSheet extends StatefulWidget {
  final String userId;
  final String reportedText;
  final String? messageId;
  final String? sceneId;

  const ContentReportSheet({
    super.key,
    required this.userId,
    required this.reportedText,
    this.messageId,
    this.sceneId,
  });

  @override
  State<ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<ContentReportSheet> {
  final _detailController = TextEditingController();

  String? _selectedReason;
  bool _isSubmitting = false;
  bool _hasError = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _hasError = false;
    });

    final detail = _detailController.text.trim();
    final reportService =
        ContentReportService.getInstance(Supabase.instance.client);
    final success = await reportService.submitReport(
      userId: widget.userId,
      reason: _selectedReason!,
      messageId: widget.messageId,
      sceneId: widget.sceneId,
      detail: detail.isEmpty ? null : detail,
      reportedText: widget.reportedText,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isSubmitting = false;
        _hasError = true;
      });
    }
  }

  Widget _buildReasonChip(String value, String label) {
    final selected = _selectedReason == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.brand.withValues(alpha: 0.15),
      onSelected: _isSubmitting
          ? null
          : (_) => setState(() => _selectedReason = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.reportSheetTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReasonChip('inappropriate', l.reportReasonInappropriate),
                _buildReasonChip('incorrect', l.reportReasonIncorrect),
                _buildReasonChip('other', l.reportReasonOther),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailController,
              enabled: !_isSubmitting,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.reportDetailHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_hasError) ...[
              const SizedBox(height: 8),
              Text(
                l.reportSubmitError,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedReason == null || _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.reportSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
