import 'package:flutter/material.dart';
import '../../models/diagnostic.dart';
import '../../services/onboarding_service.dart';

/// DiagnosticTestScreenEnhanced: 改善版診断テスト画面
/// 
/// 機能:
/// - スコア表示（リアルタイム）
/// - ヒント機能
/// - 解説テキスト
/// - 「わかりません」オプション明記
class DiagnosticTestScreenEnhanced extends StatefulWidget {
  final Function(DiagnosticResult) onTestComplete;
  final OnboardingService? analyticsService;

  const DiagnosticTestScreenEnhanced({
    Key? key,
    required this.onTestComplete,
    this.analyticsService,
  }) : super(key: key);

  @override
  State<DiagnosticTestScreenEnhanced> createState() =>
      _DiagnosticTestScreenEnhancedState();
}

class _DiagnosticTestScreenEnhancedState
    extends State<DiagnosticTestScreenEnhanced>
    with SingleTickerProviderStateMixin {
  late List<DiagnosticQuestion> questions;
  int currentQuestionIndex = 0;
  late List<int?> userAnswers;
  late List<bool> hintUsed;
  bool isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeTest();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _initializeTest() {
    questions = DiagnosticQuestionSet.getQuestions();
    userAnswers = List<int?>.filled(questions.length, null);
    hintUsed = List<bool>.filled(questions.length, false);
    setState(() {
      isLoading = false;
    });
  }

  /// 正解数を計算
  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < questions.length; i++) {
      if (userAnswers[i] == questions[i].correctAnswerIndex) {
        score++;
      }
    }
    return score;
  }


  void _handleAnswerSelected(int answerIndex) {
    setState(() {
      userAnswers[currentQuestionIndex] = answerIndex;
    });

    // アニメーション後に次問へ
    _animationController.forward().then((_) {
      _moveToNextQuestion();
    });

    // ヒント使用の記録
    if (hintUsed[currentQuestionIndex]) {
      widget.analyticsService?.recordHintUsage();
    }
  }

  void _handleShowHint() {
    if (!hintUsed[currentQuestionIndex]) {
      _showHintDialog();
      setState(() {
        hintUsed[currentQuestionIndex] = true;
      });
    }
  }

  void _handleSkip() {
    setState(() {
      userAnswers[currentQuestionIndex] = null;
    });
    _moveToNextQuestion();
    widget.analyticsService?.recordSkip();
  }

  void _moveToNextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
      _animationController.reset();
    } else {
      _submitTest();
    }
  }

  void _submitTest() {
    final score = _calculateScore();
    final level = DiagnosticResult.getLevelFromScore(score);
    final result = DiagnosticResult(
      totalScore: score,
      level: level,
      userAnswers: userAnswers,
    );
    widget.onTestComplete(result);
  }

  void _showHintDialog() {
    final hint = questions[currentQuestionIndex].hint;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ヒント'),
        content: Text(hint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showExplanation(int questionIndex, int selectedAnswer) {
    final question = questions[questionIndex];
    final isCorrect = question.correctAnswerIndex == selectedAnswer;
    final explanation = question.explanation;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCorrect ? '正解！' : '不正解です',
          style: TextStyle(
            color: isCorrect ? Colors.green : Colors.red,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '解説',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(explanation),
              const SizedBox(height: 16),
              Text(
                '正解: ${question.options[question.correctAnswerIndex]}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _moveToNextQuestion();
            },
            child: const Text('次へ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final question = questions[currentQuestionIndex];
    final currentScore = _calculateScore();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // スコア表示
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '問題 ${currentQuestionIndex + 1}/${questions.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0099FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '正解: $currentScore/${questions.length}',
                      style: const TextStyle(
                        color: Color(0xFF0099FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 難易度表示
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Chip(
                label: Text(question.difficulty),
                backgroundColor: const Color(0xFFFF9900).withValues(alpha: 0.2),
                labelStyle: const TextStyle(color: Color(0xFFFF9900)),
              ),
            ),

            // 問題文
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                question.questionText,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),

            // 選択肢
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                children: List.generate(question.options.length, (index) {
                  final option = question.options[index];
                  final isSelected = userAnswers[currentQuestionIndex] == index;
                  final isCorrectAnswer = question.correctAnswerIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ElevatedButton(
                      onPressed: () {
                        _handleAnswerSelected(index);
                        // 選択後に解説を表示
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _showExplanation(currentQuestionIndex, index);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? const Color(0xFF0099FF)
                            : Colors.white,
                        foregroundColor:
                            isSelected ? Colors.white : Colors.black,
                        side: const BorderSide(color: Color(0xFF0099FF)),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ヒントとスキップボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _handleShowHint,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(
                    hintUsed[currentQuestionIndex]
                        ? 'ヒント(使用済み)'
                        : 'ヒント',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _handleSkip,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('スキップ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
