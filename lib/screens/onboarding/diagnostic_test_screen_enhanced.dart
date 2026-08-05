import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../../models/diagnostic.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_colors.dart';

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

  /// 施策③: テスト全体を任意化するための「あとで受ける」導線。
  /// null の場合はボタンを表示しない(設定画面等からの任意受験時は
  /// 既に一度受けているか自発的に開いているため不要)。
  final VoidCallback? onSkip;

  const DiagnosticTestScreenEnhanced({
    super.key,
    required this.onTestComplete,
    this.analyticsService,
    this.onSkip,
  });

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

    // 解答時のアニメーション。次問への遷移は解説ダイアログの「次へ」ボタン
    // (_showExplanation) でのみ行う — ここで二重に呼ぶと1問飛ばしになる。
    _animationController.forward();

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
    final l10n = AppLocalizations.of(context);
    final hint = questions[currentQuestionIndex].hint;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.diagHint),
        content: Text(hint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showExplanation(int questionIndex, int selectedAnswer) {
    final l10n = AppLocalizations.of(context);
    final question = questions[questionIndex];
    final isCorrect = question.correctAnswerIndex == selectedAnswer;
    final explanation = question.explanation;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCorrect ? l10n.diagCorrect : l10n.diagIncorrect,
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
                l10n.diagExplanation,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(explanation),
              const SizedBox(height: 16),
              Text(
                l10n.diagCorrectAnswer(
                    question.options[question.correctAnswerIndex]),
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
            child: Text(l10n.next),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = questions[currentQuestionIndex];
    final currentScore = _calculateScore();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // leading(戻る矢印)はFlutterの既定動作: Navigator.canPop(context)が
      // trueの場合(設定画面等からpushされた任意受験)のみ自動表示され、
      // オンボーディング直下(push無し)では表示されない。
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(l10n.diagSkipTest),
            ),
        ],
      ),
      // SafeArea: ステータスバー（時計・電池表示）とコンテンツの重なりを防ぐ
      body: SafeArea(
        child: SingleChildScrollView(
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
                      l10n.diagQuestionProgress(
                          currentQuestionIndex + 1, questions.length),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.diagScoreCount(currentScore, questions.length),
                        style: const TextStyle(
                          color: AppColors.brand,
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
                  backgroundColor:
                      AppColors.levelIntermediate.withValues(alpha: 0.2),
                  labelStyle: const TextStyle(color: AppColors.levelIntermediate),
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // タップ時点の問題インデックスを固定で保持する。
                          // currentQuestionIndex をそのまま遅延クロージャで参照すると、
                          // 300ms待つ間に進行してしまった場合に誤った設問の解説を表示しうる。
                          final answeredQuestionIndex = currentQuestionIndex;
                          _handleAnswerSelected(index);
                          // 選択後に解説を表示
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _showExplanation(answeredQuestionIndex, index);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSelected ? AppColors.brand : Colors.white,
                          foregroundColor:
                              isSelected ? Colors.white : Colors.black,
                          side: const BorderSide(color: AppColors.brand),
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
                          ? l10n.diagHintUsed
                          : l10n.diagHint,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _handleSkip,
                    icon: const Icon(Icons.skip_next),
                    label: Text(l10n.skip),
                  ),
                ],
              ),
            ],
          ),
        ),
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
