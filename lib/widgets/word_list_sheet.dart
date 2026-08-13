import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/dictionary_service.dart';
import '../theme/app_colors.dart';

/// WordListSheet: AIメッセージ全文を渡し、AIが選んだ「学習者にとって
/// 難しい語」最大3つの詳細をまとめて表示するボトムシート(施策②)。
///
/// 従来のふりがな抽出方式(PR #48)を廃止し、単語選定自体をサーバー側の
/// AIに委ねる。ふりがなON/OFFや漢字の有無に関わらず常に呼び出せる。
class WordListSheet extends StatefulWidget {
  final String messageContent;
  final String? sceneId;
  final String? sceneLevel;
  final String? sessionId;

  const WordListSheet({
    super.key,
    required this.messageContent,
    this.sceneId,
    this.sceneLevel,
    this.sessionId,
  });

  @override
  State<WordListSheet> createState() => _WordListSheetState();
}

class _WordListSheetState extends State<WordListSheet> {
  final _dictionaryService = DictionaryService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _dictionaryService.lookupSentence(
      context: widget.messageContent,
      sceneId: widget.sceneId,
      sceneLevel: widget.sceneLevel,
      sessionId: widget.sessionId,
    );
  }

  Widget _buildRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  Widget _buildWordCard(AppLocalizations l, Map<String, dynamic> word) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word['term'] as String? ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildRow(l.wordLookupReading, word['reading'] as String?),
          _buildRow(l.wordLookupMeaningEn, word['meaning_en'] as String?),
          _buildRow(l.wordLookupMeaningFil, word['meaning_fil'] as String?),
          _buildRow(
            l.wordLookupExample,
            [word['example_ja'], word['example_en']]
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .join('\n'),
          ),
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
                  : l.wordListError;
              return SizedBox(
                height: 100,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(message, style: const TextStyle(color: Colors.grey)),
                ),
              );
            }

            final words =
                (result['data']?['words'] as List?)?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];

            if (words.isEmpty) {
              return SizedBox(
                height: 80,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.wordListEmpty,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: words.map((word) => _buildWordCard(l, word)).toList(),
            );
          },
        ),
      ),
    );
  }
}
