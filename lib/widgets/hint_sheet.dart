import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../services/hint_service.dart';
import '../theme/app_colors.dart';

/// HintSheet: 会話の続き方のヒント(次に言えそうな例文+英訳)を表示するボトムシート(T-36)。
///
/// 「この文を使う」を押すと example_ja を呼び出し元へ返す
/// (ChatScreen が入力欄へ反映する)。会話状態には直接触れない。
class HintSheet extends StatefulWidget {
  final String context;
  final String? sceneId;
  final String? sessionId;

  const HintSheet({super.key, required this.context, this.sceneId, this.sessionId});

  @override
  State<HintSheet> createState() => _HintSheetState();
}

class _HintSheetState extends State<HintSheet> {
  final _hintService = HintService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _hintService.getHint(
      context: widget.context,
      sceneId: widget.sceneId,
      sessionId: widget.sessionId,
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
                    Text(l.hintLoading),
                  ],
                ),
              );
            }

            final result = snapshot.data;
            if (result == null || result['success'] != true) {
              final error = result?['error'] as String?;
              final message =
                  error == 'quota_reached' ? l.hintQuotaReached : l.hintError;
              return SizedBox(
                height: 140,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.hintTitle,
                      style: const TextStyle(
                        fontSize: 18,
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
            final exampleJa = data['example_ja'] as String? ?? '';
            final exampleEn = data['example_en'] as String? ?? '';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.hintTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(exampleJa, style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 4),
                Text(exampleEn, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: exampleJa.isEmpty
                        ? null
                        : () => Navigator.pop(context, exampleJa),
                    child: Text(l.hintUseThis),
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
