import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
  if (dart.library.html) 'package:voikerchat/stubs/firebase_messaging_stub.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/main.dart' show RootScreen;

import '../models/diagnostic.dart';
import '../services/account_service.dart';
import '../services/learner_preferences_service.dart';
import '../services/locale_service.dart';
import '../services/notification_scheduler.dart';
import '../services/remote_notification_service.dart';
import 'onboarding/diagnostic_test_screen_enhanced.dart';

/// 設定画面。ストア必須の「アカウント削除」導線と、学習サポート設定を提供する。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AccountService _accountService = AccountService();
  final LearnerPreferencesService _learnerPreferencesService =
      LearnerPreferencesService();
  final LocaleService _localeService = LocaleService();
  final NotificationScheduler _notificationScheduler = NotificationScheduler();
  bool _deleting = false;
  bool _furiganaEnabled = true;
  bool _notificationsEnabled = true;
  String? _localeCode; // null = 端末設定に従う

  @override
  void initState() {
    super.initState();
    _loadFuriganaPreference();
    _localeCode = LocaleService.currentLocale.value?.languageCode;
    if (_notificationScheduler.isInitialized) {
      _notificationsEnabled = _notificationScheduler.isNotificationsEnabled();
    }
  }

  Future<void> _loadFuriganaPreference() async {
    final enabled = await _learnerPreferencesService.isFuriganaEnabled();
    if (!mounted) return;
    setState(() => _furiganaEnabled = enabled);
  }

  Future<void> _toggleFurigana(bool value) async {
    setState(() => _furiganaEnabled = value);
    await _learnerPreferencesService.setFuriganaEnabled(value);
  }

  /// 施策③: 診断テストをいつでも受け直せる常設導線。
  Future<void> _retakeLevelTest() async {
    final result = await Navigator.of(context).push<DiagnosticResult>(
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
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.resultScore(result.totalScore))),
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // ONにする際、OS側の通知権限が拒否済みなら設定アプリへ誘導する
      // (アプリ内トグルだけONにしても実際には届かないため)。
      AuthorizationStatus? status;
      try {
        status = await RemoteNotificationService().getAuthorizationStatus();
      } catch (_) {
        // 確認できない場合(Web等)はブロックせず進める。
      }
      if (status == AuthorizationStatus.denied) {
        await _showNotificationPermissionDeniedDialog();
        return;
      }
    }

    setState(() => _notificationsEnabled = value);
    await _notificationScheduler.setNotificationsEnabled(value);
    if (value) {
      await _notificationScheduler.scheduleDailyReminders();
    } else {
      await _notificationScheduler.cancelDailyReminders();
    }
  }

  Future<void> _showNotificationPermissionDeniedDialog() async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.notificationPermissionDeniedTitle),
        content: Text(l.notificationPermissionDeniedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              AppSettings.openAppSettings();
            },
            child: Text(l.openSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLocale(String? code) async {
    setState(() => _localeCode = code);
    await _localeService.setLocale(code);
  }

  /// 言語名は自己表記(日本語/English/Filipino)固定。どのUI言語からでも
  /// 読める必要があるため翻訳しない(キャラ名等と同じ扱い)。
  String _localeDisplayName(String? code, AppLocalizations l) {
    switch (code) {
      case 'ja':
        return '日本語';
      case 'en':
        return 'English';
      case 'fil':
        return 'Filipino';
      default:
        return l.languageFollowSystem;
    }
  }

  Widget _languageOption(String? code, String label) {
    return RadioListTile<String?>(
      title: Text(label),
      value: code,
    );
  }

  Future<void> _showLanguagePicker() async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l.languageSettingTitle),
        children: [
          RadioGroup<String?>(
            groupValue: _localeCode,
            onChanged: (value) {
              Navigator.pop(dialogContext);
              _selectLocale(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _languageOption(null, l.languageFollowSystem),
                _languageOption('ja', '日本語'),
                _languageOption('en', 'English'),
                _languageOption('fil', 'Filipino'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.deleteAccountConfirmTitle),
        content: Text(l.deleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.deleteAccountConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _accountService.deleteAccount();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.deleteAccountSuccess)),
      );
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l.deleteAccountError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: Stack(
        children: [
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l.settingsLearningSectionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.text_fields),
                title: Text(l.furiganaToggleTitle),
                subtitle: Text(l.furiganaToggleSubtitle),
                value: _furiganaEnabled,
                onChanged: _toggleFurigana,
              ),
              ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text(l.settingsRetakeLevelTest),
                onTap: _retakeLevelTest,
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l.languageSettingTitle),
                subtitle: Text(_localeDisplayName(_localeCode, l)),
                onTap: _showLanguagePicker,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(l.notificationToggleTitle),
                subtitle: Text(l.notificationToggleSubtitle),
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l.settingsAccountSectionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l.deleteAccountTitle,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: Text(l.deleteAccountSubtitle),
                enabled: !_deleting,
                onTap: _deleting ? null : _confirmAndDelete,
              ),
            ],
          ),
          if (_deleting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l.deleteAccountInProgress),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
