import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/learner_preferences_service.dart';
import '../services/recap_service.dart';
import '../services/share_card_service.dart';
import '../services/vocab_summary_service.dart';
import '../theme/app_colors.dart';

/// VocabSummarySheet: セッション終了時の学習まとめボトムシート。
///
/// 3セクション構成:
/// 1. 今日の言い直し — ユーザー発話の改善点を最大3件(original→improved+tip)。
///    競合分析(Speakの "Made for You")を参考にした個別化復習の簡易版。
/// 2. 今日の単語 — 会話の重要語を最大8個(T-36)。
/// 3. 難易度フィードバック — 3択(かんたん/ちょうどいい/むずかしい)を
///    ローカル保存し、次回会話のシステムプロンプトに反映(Duolingo Max方式)。
///
/// recap と vocab-summary は並行で取得する。表示のみ(保存・復習リスト化は
/// Phase 2 バックログ)。
class VocabSummarySheet extends StatefulWidget {
  final String conversation;
  final String? sceneId;

  const VocabSummarySheet({super.key, required this.conversation, this.sceneId});

  @override
  State<VocabSummarySheet> createState() => _VocabSummarySheetState();
}

class _VocabSummarySheetState extends State<VocabSummarySheet> {
  final _vocabSummaryService = VocabSummaryService();
  final _recapService = RecapService();
  final _learnerPreferencesService = LearnerPreferencesService();
  final _shareCardService = ShareCardService();
  late Future<List<Map<String, dynamic>>> _future;
  String? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    // 2つのAPIを並行取得(どちらかが失敗しても他方は表示する)。
    _future = Future.wait([
      _recapService.getRecap(
        conversation: widget.conversation,
        sceneId: widget.sceneId,
      ),
      _vocabSummaryService.getSummary(
        conversation: widget.conversation,
        sceneId: widget.sceneId,
      ),
    ]);
  }

  Future<void> _selectDifficulty(String value) async {
    setState(() => _selectedDifficulty = value);
    await _learnerPreferencesService.setDifficultyFeedback(value);
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  /// 「今日の言い直し」1件分: 元の発話(グレー打消し) → 自然な言い方(ブランド色) → 一言Tip。
  Widget _buildCorrectionRow(Map<String, dynamic> map) {
    final original = map['original'] as String? ?? '';
    final improved = map['improved'] as String? ?? '';
    final tip = map['tip_en'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            original,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_forward, size: 14, color: AppColors.brand),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  improved,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          if (tip.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              tip,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWordRow(Map<String, dynamic> map) {
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
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
  }

  Widget _buildDifficultySection(AppLocalizations l) {
    final options = <(String, String)>[
      ('easy', l.difficultyEasy),
      ('good', l.difficultyGood),
      ('hard', l.difficultyHard),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.difficultyQuestion,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final (value, label) = option;
            final selected = _selectedDifficulty == value;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: AppColors.brand.withValues(alpha: 0.15),
              onSelected: (_) => _selectDifficulty(value),
            );
          }).toList(),
        ),
        if (_selectedDifficulty != null) ...[
          const SizedBox(height: 6),
          Text(
            l.difficultyThanks,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
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

            final results = snapshot.data ?? [];
            final recapResult = results.isNotEmpty ? results[0] : null;
            final vocabResult = results.length > 1 ? results[1] : null;

            final corrections = (recapResult?['success'] == true)
                ? (recapResult?['corrections'] as List?) ?? []
                : <dynamic>[];
            final words = (vocabResult?['success'] == true)
                ? (vocabResult?['words'] as List?) ?? []
                : <dynamic>[];

            // シートが縦に長くなるためスクロール可能にする(小型端末対策)。
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 今日の言い直し(取得成功かつ1件以上のときのみ表示。
                    //    「直すところなし」も学習者を褒める情報として表示する)
                    if (recapResult?['success'] == true) ...[
                      _sectionTitle(l.recapSectionTitle),
                      const SizedBox(height: 12),
                      if (corrections.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            l.recapNoCorrections,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      else ...[
                        ...corrections.map(
                          (c) => _buildCorrectionRow(c as Map<String, dynamic>),
                        ),
                        // シェアカード(OS標準共有シート経由。SNS SDK不使用のため
                        // ストア申告への影響なし)。
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: Text(l.recapShare),
                            onPressed: () => _shareCardService.shareRecapCard(
                              corrections: corrections
                                  .map((c) => c as Map<String, dynamic>)
                                  .toList(),
                              title: l.recapSectionTitle,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                    // 2. 今日の単語(T-36、従来どおり)
                    _sectionTitle(l.vocabSummaryTitle),
                    const SizedBox(height: 12),
                    if (vocabResult?['success'] != true)
                      Text(
                        l.vocabSummaryError,
                        style: const TextStyle(color: Colors.grey),
                      )
                    else if (words.isEmpty)
                      Text(
                        l.vocabSummaryEmpty,
                        style: const TextStyle(color: Colors.grey),
                      )
                    else
                      ...words.map(
                        (w) => _buildWordRow(w as Map<String, dynamic>),
                      ),

                    // 3. 難易度フィードバック
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildDifficultySection(l),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.close),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
