import 'package:uuid/uuid.dart';

/// 診断テスト結果のレベル定義
enum UserDiagnosticLevel { beginner, intermediate, advanced }

/// 診断テストの問題定義
class DiagnosticQuestion {
  final String id;
  final String questionText;
  final String difficulty; // N4, N3, N2
  final List<String> options; // 4択 + わかりません（5番目）
  final int correctAnswerIndex; // 正解のインデックス（0-3）
  final String explanation; // 解説テキスト
  final String hint; // ヒントテキスト

  DiagnosticQuestion({
    String? id,
    required this.questionText,
    required this.difficulty,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.hint,
  }) : id = id ?? const Uuid().v4();
}

/// 診断テスト結果
class DiagnosticResult {
  final int totalScore; // 0-3点
  final UserDiagnosticLevel level;
  final List<int?> userAnswers; // ユーザーの選択肢（null = スキップ）
  final DateTime completedAt;

  DiagnosticResult({
    required this.totalScore,
    required this.level,
    required this.userAnswers,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  /// スコアからレベルを判定
  static UserDiagnosticLevel getLevelFromScore(int score) {
    if (score >= 3) return UserDiagnosticLevel.advanced;
    if (score >= 1) return UserDiagnosticLevel.intermediate;
    return UserDiagnosticLevel.beginner;
  }

}

/// 診断テスト問題セット（固定3問）
class DiagnosticQuestionSet {
  static List<DiagnosticQuestion> getQuestions() {
    return [
      DiagnosticQuestion(
        questionText: 'すみません、今何時ですか？',
        difficulty: 'N4',
        options: [
          '私は学生です。',
          'もう10時です。',
          '毎日学校に行きます。',
          'これはペンです。',
          'わかりません',
        ],
        correctAnswerIndex: 1,
        explanation:
            '「何時ですか？」は「今、何時ですか？」という質問です。時刻を聞いています。正解は「もう10時です。」です。',
        hint: 'この質問は「時間」について聞いています。「10時」「15時」のような答え方を探してみましょう。',
      ),
      DiagnosticQuestion(
        questionText:
            '明日の会議について、詳しく説明してもらえませんか？',
        difficulty: 'N3',
        options: [
          '昨日会議がありました。',
          'はい、明日の会議は午前10時に始まります。',
          '会議は好きです。',
          '毎週会議があります。',
          'わかりません',
        ],
        correctAnswerIndex: 1,
        explanation:
            '「詳しく説明してもらえますか」は丁寧な依頼表現です。正解は「はい、明日の会議は午前10時に始まります。」という具体的な説明です。',
        hint:
            '「詳しく説明してください」という質問に対して、具体的で詳細な情報が返される必要があります。',
      ),
      DiagnosticQuestion(
        questionText:
            '今後の事業展開において、AI技術の導入が不可欠であると考えられる。',
        difficulty: 'N2',
        options: [
          'AI技術は難しいです。',
          'これからAIを学びたいです。',
          'AI技術の導入は今後の事業に重要だと考える。',
          'AIについて知りません。',
          'わかりません',
        ],
        correctAnswerIndex: 2,
        explanation:
            '「不可欠である」は「なくてはならない、とても重要」という意味です。正解は「AI技術の導入は今後の事業に重要だと考える」で、これが「不可欠である」の意味を正しく表現しています。',
        hint:
            '「不可欠」という言葉の意味を考えてみましょう。「必要」「重要」に関連した選択肢を探してください。',
      ),
    ];
  }
}
