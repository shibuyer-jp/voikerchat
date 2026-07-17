import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/dictionary_service.dart';
import '../theme/app_colors.dart';

/// WordLookupSheet: AIメッセージ内で選択した語句の意味を表示するボトムシート(T-31)。
///
/// 会話状態(入力欄・TTS再生)を壊さないよう、独立した ModalBottomSheet として
/// 表示するだけで、呼び出し元(ChatScreen)の状態には触れない。
class WordLookupSheet extends StatefulWidget {
  final String term;
  final String context;
  final String? sceneId;

  const WordLookupSheet({
    super.key,
    required this.term,
    required this.context,
    this.sceneId,
  });

  @override
  State<WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends State<WordLookupSheet> {
  final _dictionaryService = DictionaryService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _dictionaryService.lookup(
      term: widget.term,
      context: widget.context,
      sceneId: widget.sceneId,
    );
  }

  Widget _buildRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
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
                    Text(l.wordLookupLoading),
                  ],
                ),
              );
            }

            final result = snapshot.data;
            if (result == null || result['success'] != true) {
              final error = result?['error'] as String?;
              final message = error == 'quota_reached'
                  ? l.wordLookupQuotaReached
                  : l.wordLookupError;
              return SizedBox(
                height: 140,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.term,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(message, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            final data = result['data'] as Map<String, dynamic>;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.term,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRow(l.wordLookupReading, data['reading'] as String?),
                _buildRow(l.wordLookupMeaningEn, data['meaning_en'] as String?),
                _buildRow(l.wordLookupMeaningFil, data['meaning_fil'] as String?),
                _buildRow(
                  l.wordLookupExample,
                  [data['example_ja'], data['example_en']]
                      .whereType<String>()
                      .where((s) => s.trim().isNotEmpty)
                      .join('\n'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
