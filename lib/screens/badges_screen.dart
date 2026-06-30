import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:voikerchat/l10n/app_localizations.dart';
import '../models/badge.dart';
import '../models/message.dart';
import '../services/badge_service.dart';
import '../services/message_service.dart';

/// BadgesScreen: 獲得バッジの一覧と進捗を表示する。
///
/// 無料ユーザーも閲覧可能。画面を開くたびに最新の実績で解除を再評価し、
/// 新規解除があれば SnackBar で通知する。
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final BadgeService _badgeService = BadgeService();

  bool _isLoading = true;
  String? _error;
  Set<String> _unlocked = {};
  SharedPreferences? _prefs;
  BadgeStats _stats = const BadgeStats(
    totalConversations: 0,
    basicScenesUsed: 0,
    animeScenesUsed: 0,
    maxStreakDays: 0,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();

      var sessions = <ConversationSession>[];
      if (userId != null) {
        try {
          final messageService = MessageService(Supabase.instance.client);
          sessions = await messageService.getUserSessions(userId);
        } catch (_) {
          // セッション取得失敗時はローカル実績（連続日数）のみで判定する。
          sessions = <ConversationSession>[];
        }
      }

      final stats = _badgeService.buildStats(
        userId: userId ?? 'anonymous',
        sessions: sessions,
        prefs: prefs,
      );
      final newlyUnlocked = await _badgeService.evaluateAndPersist(
        stats: stats,
        prefs: prefs,
      );
      final unlocked = _badgeService.loadUnlocked(prefs);

      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _stats = stats;
        _unlocked = unlocked;
        _isLoading = false;
      });

      if (newlyUnlocked.isNotEmpty) {
        final names = newlyUnlocked.map((b) => b.title).join('、');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 新しいバッジを獲得: $names'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'バッジの読み込みに失敗しました';
        _isLoading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).badgesTitle), elevation: 0),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _retry, child: Text(AppLocalizations.of(context).retry)),
          ],
        ),
      );
    }

    final total = BadgeCatalog.all.length;
    final unlockedCount = _unlocked.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFC107)),
              const SizedBox(width: 8),
              Text(
                '$unlockedCount / $total 個獲得',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: BadgeCatalog.all.length,
            itemBuilder: (context, index) {
              final badge = BadgeCatalog.all[index];
              final isUnlocked = _unlocked.contains(badge.id);
              final unlockedAt = (isUnlocked && _prefs != null)
                  ? _badgeService.unlockedAt(_prefs!, badge.id)
                  : null;
              return _BadgeCard(
                badge: badge,
                isUnlocked: isUnlocked,
                current: _stats.currentValueFor(badge.conditionType),
                unlockedAt: unlockedAt,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.badge,
    required this.isUnlocked,
    required this.current,
    required this.unlockedAt,
  });

  final AppBadge badge;
  final bool isUnlocked;
  final int current;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final progress = (current / badge.threshold).clamp(0.0, 1.0).toDouble();
    final iconColor = isUnlocked ? badge.color : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? badge.color.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? badge.color.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUnlocked ? badge.icon : Icons.lock_outline,
            size: 40,
            color: iconColor,
          ),
          const SizedBox(height: 8),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          if (isUnlocked)
            Text(
              unlockedAt != null
                  ? '${unlockedAt!.year}/${unlockedAt!.month}/${unlockedAt!.day} 獲得'
                  : '獲得済み',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  badge.color.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$current / ${badge.threshold}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
