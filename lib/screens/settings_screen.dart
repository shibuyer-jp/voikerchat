import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:voikerchat/main.dart' show RootScreen;

import '../services/account_service.dart';
import '../services/learner_preferences_service.dart';

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
  bool _deleting = false;
  bool _furiganaEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadFuriganaPreference();
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
