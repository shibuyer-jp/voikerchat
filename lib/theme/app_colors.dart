import 'package:flutter/material.dart';

/// Voikerchat ブランドカラー定数(T-30)。
///
/// [brand] はアプリアイコン(assets/icon/app_icon_1024.png)の主要色を
/// 抽出して決定(2026-07-17、docs/tasks/PROGRESS.md 判断記録参照)。
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFFC73E3A);

  /// 診断レベルタグ(scene_preview_card / diagnostic 系画面で共有)
  static const Color levelBeginner = Color(0xFF66BB6A);
  static const Color levelIntermediate = Color(0xFFFF9800);
  static const Color levelAdvanced = Color(0xFFEF5350);

  /// オンボーディング進捗インジケーター
  static const Color progressInactive = Color(0xFFE0E0E0);
  static const Color progressComplete = Color(0xFF00CC00);
  static const Color progressIncomplete = Color(0xFFCCCCCC);

  /// Premium バッジ(シーンカード上の "PREMIUM" タグ)
  static const Color premiumBackground = Color(0xFFFFD700);
  static const Color premiumText = Color(0xFFB8860B);
}
