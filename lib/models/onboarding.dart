import 'package:uuid/uuid.dart';
import 'diagnostic.dart';

/// ユーザーレベル定義
enum UserLevel { beginner, intermediate, advanced }

/// オンボーディング全体の状態
class OnboardingState {
  final String userId;
  final bool diagnosisDone;
  final DiagnosticResult? diagnosticResult;
  final UserLevel? selectedLevel;
  final String? selectedScene;
  final bool onboardingCompleted;

  OnboardingState({
    String? userId,
    this.diagnosisDone = false,
    this.diagnosticResult,
    this.selectedLevel,
    this.selectedScene,
    this.onboardingCompleted = false,
  }) : userId = userId ?? const Uuid().v4();

  /// 診断完了後の新しい状態を返す
  OnboardingState withDiagnosticResult(DiagnosticResult result) {
    return OnboardingState(
      userId: userId,
      diagnosisDone: true,
      diagnosticResult: result,
      selectedLevel: _levelFromDiagnostic(result.level),
      selectedScene: selectedScene,
      onboardingCompleted: onboardingCompleted,
    );
  }

  /// レベル選択時の新しい状態を返す
  OnboardingState withSelectedLevel(UserLevel level) {
    return OnboardingState(
      userId: userId,
      diagnosisDone: diagnosisDone,
      diagnosticResult: diagnosticResult,
      selectedLevel: level,
      selectedScene: selectedScene,
      onboardingCompleted: onboardingCompleted,
    );
  }

  /// シーン選択時の新しい状態を返す
  OnboardingState withSelectedScene(String scene) {
    return OnboardingState(
      userId: userId,
      diagnosisDone: diagnosisDone,
      diagnosticResult: diagnosticResult,
      selectedLevel: selectedLevel,
      selectedScene: scene,
      onboardingCompleted: true,
    );
  }

  /// 診断結果からレベルに変換
  static UserLevel _levelFromDiagnostic(UserDiagnosticLevel diagnosticLevel) {
    switch (diagnosticLevel) {
      case UserDiagnosticLevel.beginner:
        return UserLevel.beginner;
      case UserDiagnosticLevel.intermediate:
        return UserLevel.intermediate;
      case UserDiagnosticLevel.advanced:
        return UserLevel.advanced;
    }
  }
}

/// 13シーン定義
class SceneDefinition {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<UserLevel> recommendedLevels;
  final String character;

  const SceneDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.recommendedLevels,
    required this.character,
  });

  static List<SceneDefinition> getAllScenes() {
    return [
      // 基本8シーン
      SceneDefinition(
        id: 'cafe_friend',
        name: '友達とカフェ',
        emoji: '☕',
        description: 'カジュアルな日常会話',
        recommendedLevels: [UserLevel.beginner],
        character: 'さくら',
      ),
      SceneDefinition(
        id: 'restaurant_order',
        name: 'レストランで注文',
        emoji: '🍽️',
        description: '敬語を使った実用日本語',
        recommendedLevels: [UserLevel.intermediate],
        character: 'たくや',
      ),
      SceneDefinition(
        id: 'shopping',
        name: '買い物',
        emoji: '🛍️',
        description: '買い物表現・色・衣類・値段',
        recommendedLevels: [UserLevel.intermediate],
        character: 'ゆみ',
      ),
      SceneDefinition(
        id: 'train',
        name: '電車で移動',
        emoji: '🚋',
        description: '交通表現・方向指示・地名',
        recommendedLevels: [UserLevel.intermediate],
        character: 'こうき',
      ),
      SceneDefinition(
        id: 'hospital',
        name: '病院',
        emoji: '🏥',
        description: '医療用語・症状説明',
        recommendedLevels: [UserLevel.intermediate],
        character: 'あかり',
      ),
      SceneDefinition(
        id: 'self_introduction',
        name: '自己紹介',
        emoji: '🎤',
        description: 'ビジネス敬語・キャリア表現',
        recommendedLevels: [UserLevel.advanced],
        character: 'けんじ',
      ),
      SceneDefinition(
        id: 'cafe_relax',
        name: 'カフェでゆったり',
        emoji: '☕',
        description: 'カジュアルな会話・趣味',
        recommendedLevels: [UserLevel.beginner],
        character: 'みなと',
      ),
      SceneDefinition(
        id: 'free_talk',
        name: 'フリートーク',
        emoji: '💬',
        description: '自由表現・質問スキル',
        recommendedLevels: [UserLevel.beginner, UserLevel.intermediate, UserLevel.advanced],
        character: 'えいこ',
      ),
      // アニメ風5シーン
      SceneDefinition(
        id: 'battle_scene',
        name: '熱血戦闘シーン',
        emoji: '⚡',
        description: '命令形・感情表現',
        recommendedLevels: [UserLevel.intermediate],
        character: 'ライキ',
      ),
      SceneDefinition(
        id: 'friendship',
        name: '友情協力シーン',
        emoji: '🤝',
        description: '感謝表現・協調性',
        recommendedLevels: [UserLevel.beginner],
        character: 'ハナ',
      ),
      SceneDefinition(
        id: 'emotional',
        name: '感動涙シーン',
        emoji: '😢',
        description: '感情語彙・深い会話',
        recommendedLevels: [UserLevel.intermediate],
        character: 'ルナ',
      ),
      SceneDefinition(
        id: 'school_daily',
        name: '日常学園シーン',
        emoji: '📚',
        description: '学校用語・若者言語',
        recommendedLevels: [UserLevel.intermediate],
        character: 'タロウ',
      ),
      SceneDefinition(
        id: 'gag_talk',
        name: 'ギャグ会話',
        emoji: '😂',
        description: 'ユーモア・ワードプレイ',
        recommendedLevels: [UserLevel.beginner, UserLevel.intermediate, UserLevel.advanced],
        character: 'ジロー',
      ),
    ];
  }

  static SceneDefinition? getSceneById(String id) {
    try {
      return getAllScenes().firstWhere((scene) => scene.id == id);
    } catch (e) {
      return null;
    }
  }
}
