import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/models/diagnostic.dart';

/// モデル/サービス層のID・enum を、画面表示用の翻訳文字列へ解決するヘルパー。
///
/// 目的: データ層（BuildContext を持たない）に日本語を直書きせず、
/// 表示の瞬間に `AppLocalizations`（=画面の翻訳辞書）から引く。

/// 診断レベル enum → 表示名。
String levelName(AppLocalizations l10n, UserDiagnosticLevel level) {
  switch (level) {
    case UserDiagnosticLevel.beginner:
      return l10n.levelBeginner;
    case UserDiagnosticLevel.intermediate:
      return l10n.levelIntermediate;
    case UserDiagnosticLevel.advanced:
      return l10n.levelAdvanced;
  }
}

/// enum 名トークン（'beginner' 等）→ 表示名。
/// sceneData マップ経由で渡されたレベルの解決に使用。
String levelNameFromToken(AppLocalizations l10n, String? token) {
  switch (token) {
    case 'beginner':
      return l10n.levelBeginner;
    case 'intermediate':
      return l10n.levelIntermediate;
    case 'advanced':
      return l10n.levelAdvanced;
    default:
      return token ?? '';
  }
}

/// 通知履歴の相対時刻（秒）→ 表示ラベル。
String relativeTimeLabel(AppLocalizations l10n, int seconds) {
  if (seconds < 60) return l10n.timeJustNow;
  if (seconds < 3600) return l10n.minutesAgo(seconds ~/ 60);
  if (seconds < 86400) return l10n.hoursAgo(seconds ~/ 3600);
  if (seconds < 2592000) return l10n.daysAgo(seconds ~/ 86400); // 30日未満
  return l10n.monthsAgo(seconds ~/ 2592000);
}

/// バッジID → タイトル。
String badgeTitle(AppLocalizations l10n, String id) {
  switch (id) {
    case 'first_step':
      return l10n.badgeFirstStepTitle;
    case 'talkative_10':
      return l10n.badgeTalkative10Title;
    case 'conversation_master_50':
      return l10n.badgeConversationMaster50Title;
    case 'basic_master':
      return l10n.badgeBasicMasterTitle;
    case 'anime_explorer':
      return l10n.badgeAnimeExplorerTitle;
    case 'anime_master':
      return l10n.badgeAnimeMasterTitle;
    case 'streak_3':
      return l10n.badgeStreak3Title;
    case 'streak_7':
      return l10n.badgeStreak7Title;
    case 'streak_30':
      return l10n.badgeStreak30Title;
    default:
      return id;
  }
}

/// バッジID → 説明。
String badgeDesc(AppLocalizations l10n, String id) {
  switch (id) {
    case 'first_step':
      return l10n.badgeFirstStepDesc;
    case 'talkative_10':
      return l10n.badgeTalkative10Desc;
    case 'conversation_master_50':
      return l10n.badgeConversationMaster50Desc;
    case 'basic_master':
      return l10n.badgeBasicMasterDesc;
    case 'anime_explorer':
      return l10n.badgeAnimeExplorerDesc;
    case 'anime_master':
      return l10n.badgeAnimeMasterDesc;
    case 'streak_3':
      return l10n.badgeStreak3Desc;
    case 'streak_7':
      return l10n.badgeStreak7Desc;
    case 'streak_30':
      return l10n.badgeStreak30Desc;
    default:
      return '';
  }
}
