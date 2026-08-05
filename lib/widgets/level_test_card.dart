import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../models/diagnostic.dart';
import '../screens/onboarding/diagnostic_test_screen_enhanced.dart';
import '../services/learner_preferences_service.dart';
import '../theme/app_colors.dart';

/// LevelTestCard: 診断テスト未受験のユーザーに、あとから受けられる導線を
/// 示すカード(施策③)。シーン選択画面の「あなたへのおすすめ」見出しの
/// 上に配置する。
///
/// 表示条件: diagnostic_test_completed が false、かつ
/// 「あとで」を今日押していない場合のみ。
class LevelTestCard extends StatefulWidget {
  /// テスト完了(再受験含む)でレベルが更新された際に呼ばれる。
  /// 呼び出し元(SceneSelectionScreen経由でHomeScreen)がレベルを
  /// 再取得して「あなたへのおすすめ」に反映するために使う。
  final VoidCallback? onLevelUpdated;

  const LevelTestCard({super.key, this.onLevelUpdated});

  @override
  State<LevelTestCard> createState() => _LevelTestCardState();
}

class _LevelTestCardState extends State<LevelTestCard> {
  final _learnerPreferencesService = LearnerPreferencesService();
  bool _loading = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    final completed = await _learnerPreferencesService.isDiagnosticTestCompleted();
    final dismissedToday =
        await _learnerPreferencesService.isLevelTestCardDismissedToday();
    if (!mounted) return;
    setState(() {
      _visible = !completed && !dismissedToday;
      _loading = false;
    });
  }

  Future<void> _dismissForToday() async {
    await _learnerPreferencesService.dismissLevelTestCardForToday();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  Future<void> _takeTest() async {
    final result = await Navigator.push<DiagnosticResult>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => DiagnosticTestScreenEnhanced(
          onTestComplete: (r) => Navigator.of(routeContext).pop(r),
        ),
      ),
    );
    if (result == null || !mounted) return;

    await _learnerPreferencesService.setUserDiagnosticLevel(result.level);
    await _learnerPreferencesService.setDiagnosticTestCompleted(true);

    if (!mounted) return;
    setState(() => _visible = false);
    widget.onLevelUpdated?.call();

    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.resultScore(result.totalScore))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_visible) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.brand.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.levelTestCardTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              l.levelTestCardSubtitle,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _takeTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l.levelTestCardTakeButton),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _dismissForToday,
                  child: Text(l.later),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
