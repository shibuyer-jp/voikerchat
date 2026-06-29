import 'dart:math';
import '../models/diagnostic.dart';

/// Scene定義
class Scene {
  final int id;
  final String name;
  final String characterName;
  final String description;
  final UserDiagnosticLevel recommendedLevel;
  final String color;
  final bool isPremium;

  Scene({
    required this.id,
    required this.name,
    required this.characterName,
    required this.description,
    required this.recommendedLevel,
    required this.color,
    this.isPremium = false,
  });

  /// ChatScreen に渡す sceneData マップへ変換
  Map<String, dynamic> toSceneData() {
    return {
      'id': id,
      'name': name,
      'character': characterName,
      'description': description,
      'level': DiagnosticResult.getLevelLabel(recommendedLevel),
      'color': color,
      'isPremium': isPremium,
    };
  }
}

/// SceneService: シーン管理・フィルタリング
class SceneService {
  static final List<Scene> allScenes = [
    // 基本8シーン
    Scene(
      id: 1,
      name: '友達',
      characterName: 'Emi',
      description: '友人との日常会話',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#0099FF',
    ),
    Scene(
      id: 2,
      name: 'レストラン',
      characterName: 'Taro',
      description: '食事をしながらの丁寧な会話',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF9900',
    ),
    Scene(
      id: 3,
      name: '買い物',
      characterName: 'Akiko',
      description: '商品説明・値段交渉',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF66CC',
    ),
    Scene(
      id: 4,
      name: '電車',
      characterName: 'Yuki',
      description: '公共交通での会話',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF0000',
    ),
    Scene(
      id: 5,
      name: '病院',
      characterName: 'Dr. Nakamura',
      description: '医療表現・症状説明',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#CCCCCC',
    ),
    Scene(
      id: 6,
      name: '自己紹介',
      characterName: 'Kenji',
      description: '自分の背景を説明する',
      recommendedLevel: UserDiagnosticLevel.advanced,
      color: '#006633',
    ),
    Scene(
      id: 7,
      name: 'カフェ',
      characterName: 'Hana',
      description: 'カフェでのリラックス会話',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#8B4513',
    ),
    Scene(
      id: 8,
      name: 'フリートーク',
      characterName: 'AI',
      description: '自由な話題で練習',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#9933FF',
    ),

    // アニメ5シーン
    Scene(
      id: 9,
      name: '熱血戦闘',
      characterName: 'Raiden',
      description: '意志表明・強い決意表現',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF3333',
      isPremium: true,
    ),
    Scene(
      id: 10,
      name: '友情協力',
      characterName: 'Sakura & Lily',
      description: '励ましの表現・チームワーク',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#FF99FF',
      isPremium: true,
    ),
    Scene(
      id: 11,
      name: '感動涙',
      characterName: 'Grandmother',
      description: '感情表現・感謝',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#CC99FF',
      isPremium: true,
    ),
    Scene(
      id: 12,
      name: '日常学園',
      characterName: 'Classmates',
      description: '学校語彙・同年代会話',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#00CCFF',
      isPremium: true,
    ),
    Scene(
      id: 13,
      name: 'ギャグ会話',
      characterName: 'Tanaka',
      description: 'ユーモア理解・自然な反応',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#FFFF00',
      isPremium: true,
    ),
  ];

  /// レベル別にシーンをフィルタリング
  static List<Scene> filterByLevel(UserDiagnosticLevel level) {
    return allScenes
        .where((scene) => _isLevelMatch(scene.recommendedLevel, level))
        .toList();
  }

  /// レベル一致判定（推奨以下のレベルも表示）
  static bool _isLevelMatch(
    UserDiagnosticLevel recommended,
    UserDiagnosticLevel userLevel,
  ) {
    final recommendedValue = _levelToInt(recommended);
    final userValue = _levelToInt(userLevel);
    return userValue >= recommendedValue;
  }

  static int _levelToInt(UserDiagnosticLevel level) {
    switch (level) {
      case UserDiagnosticLevel.beginner:
        return 0;
      case UserDiagnosticLevel.intermediate:
        return 1;
      case UserDiagnosticLevel.advanced:
        return 2;
    }
  }

  /// ランダムなシーンを選択
  static Scene getRandomScene() {
    return allScenes[Random().nextInt(allScenes.length)];
  }

  /// ユーザーレベル別のランダムシーン
  static Scene getRandomSceneForLevel(UserDiagnosticLevel level) {
    final filtered = filterByLevel(level);
    return filtered.isEmpty
        ? allScenes[0]
        : filtered[Random().nextInt(filtered.length)];
  }

  /// シーンを ID で取得
  static Scene? getSceneById(int id) {
    try {
      return allScenes.firstWhere((scene) => scene.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 全シーンを取得（推奨順）
  static List<Scene> getAllScenes() => List.from(allScenes);

  /// 無料シーン（isPremium == false）
  static List<Scene> getFreeScenes() =>
      allScenes.where((scene) => !scene.isPremium).toList();

  /// プレミアムシーン（isPremium == true）
  static List<Scene> getPremiumScenes() =>
      allScenes.where((scene) => scene.isPremium).toList();
}
