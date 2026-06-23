import 'package:flutter/material.dart';
import '../../models/diagnostic.dart';
import '../../widgets/question_card.dart';

class DiagnosticTestScreen extends StatefulWidget {
  final Function(DiagnosticResult) onTestComplete;

  const DiagnosticTestScreen({
    Key? key,
    required this.onTestComplete,
  }) : super(key: key);

  @override
  State<DiagnosticTestScreen> createState() => _DiagnosticTestScreenState();
}

class _DiagnosticTestScreenState extends State<DiagnosticTestScreen> {
  late List<DiagnosticQuestion> questions;
  int currentQuestionIndex = 0;
  late List<int?> userAnswers;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  void _initializeTest() {
    questions = DiagnosticQuestionSet.getQuestions();
    userAnswers = List<int?>.filled(questions.length, null);
    setState(() {
      isLoading = false;
    });
  }

  void _handleAnswerSelected(int answerIndex) {
    setState(() {
      userAnswers[currentQuestionIndex] = answerIndex;
    });
    _moveToNextQuestion();
  }

  void _handleSkip() {
    // スキップは答えを nil で記録（0点）
    setState(() {
      userAnswers[currentQuestionIndex] = null;
    });
    _moveToNextQuestion();
  }

  void _moveToNextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    } else {
      _completeTest();
    }
  }

  void _completeTest() {
    // スコア計算
    int score = 0;
    for (int i = 0; i < userAnswers.length; i++) {
      if (userAnswers[i] != null &&
          userAnswers[i]! < questions[i].options.length - 1) {
        // わかりません（4番目）を除外
        if (userAnswers[i] == questions[i].correctAnswerIndex) {
          score++;
        }
      }
    }

    final result = DiagnosticResult(
      totalScore: score,
      level: DiagnosticResult.getLevelFromScore(score),
      userAnswers: userAnswers,
    );

    widget.onTestComplete(result);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: null,
        automaticallyImplyLeading: false,
        title: LinearProgressIndicator(
          value: (currentQuestionIndex + 1) / questions.length,
          minHeight: 8,
          backgroundColor: Colors.grey.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.blue.withOpacity(0.7),
          ),
        ),
      ),
      body: QuestionCard(
        question: questions[currentQuestionIndex],
        selectedIndex: userAnswers[currentQuestionIndex],
        onSkip: _handleSkip,
        onSelectAnswer: _handleAnswerSelected,
        questionNumber: currentQuestionIndex + 1,
        totalQuestions: questions.length,
      ),
    );
  }
}
