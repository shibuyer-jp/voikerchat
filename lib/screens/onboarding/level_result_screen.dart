import 'package:flutter/material.dart';
import '../../models/diagnostic.dart';

class LevelResultScreen extends StatelessWidget {
  final DiagnosticResult result;
  final VoidCallback onContinue;

  const LevelResultScreen({
    super.key,
    required this.result,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final levelLabel = DiagnosticResult.getLevelLabel(result.level);
    final levelColor = _getLevelColor(result.level);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // タイトル
              const Text(
                'あなたのレベルは',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // レベル表示（大きく）
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      levelColor.withValues(alpha: 0.15),
                      levelColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: levelColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      levelLabel,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'スコア: ${result.totalScore}/3',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // レベル説明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getLevelDescription(result.level),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),

              // 説明テキスト
              const Text(
                'このレベルに合わせたシーンがおすすめされます。\nいつでもレベルを変更できます。',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 次へボタン
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'シーン選択へ進む',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(UserDiagnosticLevel level) {
    switch (level) {
      case UserDiagnosticLevel.beginner:
        return Colors.blue;
      case UserDiagnosticLevel.intermediate:
        return Colors.orange;
      case UserDiagnosticLevel.advanced:
        return Colors.red;
    }
  }

  String _getLevelDescription(UserDiagnosticLevel level) {
    switch (level) {
      case UserDiagnosticLevel.beginner:
        return '初心者向けシーン（友達とのカジュアルな会話など）から始めるのがおすすめです。基礎的な日本語表現を学べます。';
      case UserDiagnosticLevel.intermediate:
        return '中級者向けシーン（レストランでの注文、買い物など）がおすすめです。敬語や実用的な日本語表現を習得できます。';
      case UserDiagnosticLevel.advanced:
        return '上級者向けシーン（自己紹介、複雑な会話など）がおすすめです。ビジネス敬語や高度な表現に挑戦できます。';
    }
  }
}
