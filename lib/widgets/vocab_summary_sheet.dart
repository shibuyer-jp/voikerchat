import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/vocab_summary_service.dart';
import '../theme/app_colors.dart';

/// VocabSummarySheet: セッション終了時の「今日の単語」ボトムシート(T-36)。
///
/// 直近の会話ログから重要語を最大8個、語+読み+英訳で表示する。
/// 表示のみ(保存・復習リスト化は Phase 2 バックログ)。
class VocabSummarySheet extends StatefulWidget {
  final String conversation;
  final String? sceneId;

  const VocabSummarySheet({super.key, required this.conversation, this.sceneId});

  @override
  State<VocabSummarySheet> createState() => _VocabSummarySheetState();
}

class _VocabSummarySheetState extends State<VocabSummarySheet> {
  final _vocabSummaryService = VocabSummaryService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _vocabSummaryService.getSummary(
      conversation: widget.conversation,
      sceneId: widget.sceneId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                height: 160,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l.vocabSummaryLoading),
                  ],
                ),
              );
            }

            final result = snapshot.data;
            final words = (result?['success'] == true)
                ? (result?['words'] as List?) ?? []
                : <dynamic>[];

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.vocabSummaryTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (result?['success'] != true)
                  Text(l.vocabSummaryError, style: const TextStyle(color: Colors.grey))
                else if (words.isEmpty)
                  Text(l.vocabSummaryEmpty, style: const TextStyle(color: Colors.grey))
                else
                  ...words.map((w) {
                    final map = w as Map<String, dynamic>;
                    final word = map['word'] as String? ?? '';
                    final reading = map['reading'] as String? ?? '';
                    final meaning = map['meaning_en'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.brand,
                                  ),
                                ),
                                if (reading.isNotEmpty)
                                  Text(
                                    reading,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(meaning, style: const TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.close),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
