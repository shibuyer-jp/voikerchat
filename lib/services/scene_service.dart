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
      'level': recommendedLevel.name,
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
      characterName: 'Sakura',
      description: '友人との日常会話',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#0099FF',
    ),
    Scene(
      id: 2,
      name: 'レストラン',
      characterName: 'Takuya',
      description: '食事をしながらの丁寧な会話',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF9900',
    ),
    Scene(
      id: 3,
      name: '買い物',
      characterName: 'Yumi',
      description: '商品説明・値段交渉',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF66CC',
    ),
    Scene(
      id: 4,
      name: '電車',
      characterName: 'Kouki',
      description: '公共交通での会話',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF0000',
    ),
    Scene(
      id: 5,
      name: '病院',
      characterName: 'Akari',
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
      characterName: 'Minato',
      description: 'カフェでのリラックス会話',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#8B4513',
    ),
    Scene(
      id: 8,
      name: 'フリートーク',
      characterName: 'Eiko',
      description: '自由な話題で練習',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#9933FF',
    ),

    // アニメ5シーン
    Scene(
      id: 9,
      name: '熱血戦闘',
      characterName: 'Raiki',
      description: '意志表明・強い決意表現',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#FF3333',
      isPremium: true,
    ),
    Scene(
      id: 10,
      name: '友情協力',
      characterName: 'Hana',
      description: '励ましの表現・チームワーク',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#FF99FF',
      isPremium: true,
    ),
    Scene(
      id: 11,
      name: '感動涙',
      characterName: 'Luna',
      description: '感情表現・感謝',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#CC99FF',
      isPremium: true,
    ),
    Scene(
      id: 12,
      name: '日常学園',
      characterName: 'Taro',
      description: '学校語彙・同年代会話',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#00CCFF',
      isPremium: true,
    ),
    Scene(
      id: 13,
      name: 'ギャグ会話',
      characterName: 'Jiro',
      description: 'ユーモア理解・自然な反応',
      recommendedLevel: UserDiagnosticLevel.beginner,
      color: '#FFFF00',
      isPremium: true,
    ),

    // 実用プレミアム5シーン(T-34): 「日本で働く外国人」視点。Kaigotalk市場検証(id 14/15)。
    Scene(
      id: 14,
      name: '介護のしごと',
      characterName: 'Haruko',
      description: '介護施設での声かけ・体調確認',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#8FBC8F',
      isPremium: true,
    ),
    Scene(
      id: 15,
      name: '医療スタッフ',
      characterName: 'Mori',
      description: '医療現場での申し送り・報告',
      recommendedLevel: UserDiagnosticLevel.advanced,
      color: '#4682B4',
      isPremium: true,
    ),
    Scene(
      id: 16,
      name: '面接',
      characterName: 'Sato',
      description: '特定技能・就労面接の練習',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#2F4F4F',
      isPremium: true,
    ),
    Scene(
      id: 17,
      name: '役所・手続き',
      characterName: 'Mizuki',
      description: '在留・住民票などの窓口手続き',
      recommendedLevel: UserDiagnosticLevel.intermediate,
      color: '#B8860B',
      isPremium: true,
    ),
    Scene(
      id: 18,
      name: '職場の敬語',
      characterName: 'Tanaka',
      description: '報連相・依頼・謝罪の敬語',
      recommendedLevel: UserDiagnosticLevel.advanced,
      color: '#36454F',
      isPremium: true,
    ),
  ];


  /// シーン別オープニング第一声（AIキャラクターの最初の発話）。
  /// 出典キャラクター設定: docs/Persona-Design-v1.0.md
  /// 会話コンテンツ（練習対象の日本語）のため i18n(ARB) 対象外。
  static const Map<int, String> openingLines = {
    1: 'あ、おまたせ！来てくれてありがとう。最近どう？なにか楽しいことあった？',
    2: 'いらっしゃいませ。お席へどうぞ。こちらがメニューでございます。本日のおすすめは日替わりパスタです。ご注文はお決まりですか？',
    3: 'いらっしゃいませ！なにかお探しですか？ちょうど新作が入ったばかりなんですよ。',
    4: 'あ、この電車は新宿方面ですよ。どちらまで行かれるんですか？',
    5: 'こんにちは。本日はどうされましたか？初めての方は、こちらの問診票にご記入をお願いします。',
    6: '初めまして、けんじと申します。本日はよろしくお願いいたします。よろしければ、お名前とご出身を教えていただけますか？',
    7: 'いい雰囲気のカフェだね。ここのコーヒー、おいしいんだよ。最近なにか面白いことあった？',
    8: 'こんにちは！今日はなにについて話しましょうか？好きな話題でいいですよ。',
    9: 'おう、来たな！今日も特訓の時間だ！まずはお前の目標を聞かせてくれ！',
    10: 'やっほー！会えてうれしい！ねえ、今日は一緒になにをがんばる？',
    11: '……来てくれたんだね。ありがとう。今日は、少しだけ昔の話をしてもいいかな。',
    12: 'おっす、おはよう！昨日の宿題やった？オレ、まだ全然終わってないんだけど！',
    13: 'どうもどうも〜！ジローです！いきなりですが…今日はどんな話でツッコんでくれる？',
    14: 'あら、来てくれたのね。今日もよろしくお願いします。ちょっと体がだるいんだけど、大丈夫かしら。',
    15: 'お疲れ様です。それでは、担当の患者さんの状態を教えてください。バイタルはどうでしたか？',
    16: '本日はお忙しい中、面接にお越しいただきありがとうございます。それでは、まず自己紹介をお願いできますか？',
    17: 'いらっしゃいませ。本日はどのようなお手続きでしょうか？在留カードの更新ですか？',
    18: 'おう、ちょっといいか。例の件、進捗はどうなってる？報告してくれ。',
  };

  /// sceneId（文字列）からオープニング第一声を取得。未定義シーンは null。
  static String? openingLineFor(String sceneId) {
    final id = int.tryParse(sceneId);
    if (id == null) return null;
    return openingLines[id];
  }

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

  /// プレミアム実用シーン(id 14〜18: 就労・生活の実務シーン。T-34)
  static List<Scene> getPremiumPracticalScenes() =>
      allScenes.where((scene) => scene.isPremium && scene.id >= 14).toList();

  /// プレミアムアニメシーン(id 9〜13)
  static List<Scene> getPremiumAnimeScenes() =>
      allScenes.where((scene) => scene.isPremium && scene.id < 14).toList();
}
