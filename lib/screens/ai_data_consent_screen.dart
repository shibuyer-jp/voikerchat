import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voikerchat/l10n/app_localizations.dart';

/// SharedPreferences キー（AIへのデータ送信同意の永続化）。
/// is_first_launch とは独立して判定するため別キーにしている
/// (App Store Guideline 5.1.1(i)/5.1.2(i)対応、2026-08-03リジェクト。
/// 既存ユーザーにも次回起動時に表示する必要があるため)。
const String kAiDataConsentAcceptedKey = 'ai_data_consent_accepted';

/// AIサービスへのデータ送信に関する同意画面。
///
/// 新規ユーザーはオンボーディングの直前、既存ユーザーは次回起動時に
/// (is_first_launchの状態によらず)単独で表示される。「同意して続ける」を
/// 押すまでは [nextScreen] へ進めない。「同意しない」は説明を表示して
/// この画面に留まる(案A、同意なしではアプリを利用不可)。
class AiDataConsentScreen extends StatelessWidget {
  final Widget nextScreen;

  const AiDataConsentScreen({super.key, required this.nextScreen});

  Future<void> _accept(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kAiDataConsentAcceptedKey, true);
    } catch (e) {
      // 保存に失敗しても致命的ではない。次回起動時にこの画面が
      // 再度表示されるだけで、アプリはクラッシュさせない。
    }
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  void _showDeclineExplanation(BuildContext context) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l.aiConsentDeclineExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    // アプリ内リンクは既存のpaywall_screen.dartと同じ固定ドメイン。
    // 英語ロケールのときのみ-en版を開く(fil版のページが無いためjaへフォールバック、
    // 既存のpaywall_screen.dartと同じ扱い)。
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final path = isEnglish ? 'Privacy-Policy-v1.0-en' : 'Privacy-Policy-v1.0';
    final uri = Uri.parse('https://voikerchat.com/$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.privacy_tip_outlined, size: 48),
              const SizedBox(height: 24),
              Text(
                l.aiConsentTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(l.aiConsentBody),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _openPrivacyPolicy(context),
                  child: Text(l.privacyPolicy),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _accept(context),
                child: Text(l.aiConsentAccept),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showDeclineExplanation(context),
                child: Text(l.aiConsentDecline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
