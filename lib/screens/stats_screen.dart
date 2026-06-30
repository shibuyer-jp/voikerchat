import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Stats Dashboard Screen for Premium Users
///
/// Displays learning progress, token usage, scene progress, etc.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  // Error is stored as a code (+ optional detail) and localized at build time,
  // so we never need a BuildContext inside the async loader.
  String? _errorCode; // 'auth' | 'premium' | 'load' | 'exception'
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) {
        setState(() {
          _errorCode = 'auth';
          _isLoading = false;
        });
        return;
      }

      const baseUrl = 'https://voikerchat.com';
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics?token=$token'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats = data['stats'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      } else if (response.statusCode == 403) {
        setState(() {
          _errorCode = 'premium';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorCode = 'load';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorCode = 'exception';
        _errorDetail = e.toString();
        _isLoading = false;
      });
    }
  }

  String _errorText(AppLocalizations l) {
    switch (_errorCode) {
      case 'auth':
        return l.statsErrorNotAuthenticated;
      case 'premium':
        return l.statsErrorPremiumRequired;
      case 'exception':
        return l.statsErrorLoading(_errorDetail ?? '');
      case 'load':
      default:
        return l.statsErrorLoadFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('📊 ${l.learningStats}'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorCode != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorText(l), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStats,
                        child: Text(l.retry),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Cards
                      _buildOverviewSection(l),
                      const SizedBox(height: 24),

                      // Engagement Section
                      _buildEngagementSection(l),
                      const SizedBox(height: 24),

                      // Scene Progress
                      _buildSceneProgressSection(l),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverviewSection(AppLocalizations l) {
    final overview = (_stats?['overview'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.statsOverview,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _StatCard(
              icon: '🔥',
              title: l.statsSessions,
              value: '${overview['totalSessions'] ?? 0}',
              color: Colors.orange,
            ),
            _StatCard(
              icon: '⏱️',
              title: l.statsLearningHours,
              value: '${overview['estimatedLearningHours'] ?? 0}h',
              color: Colors.blue,
            ),
            _StatCard(
              icon: '📝',
              title: l.statsTotalTokens,
              value: '${overview['totalTokens'] ?? 0}',
              color: Colors.green,
            ),
            _StatCard(
              icon: '📅',
              title: l.statsToday,
              value: '${overview['tokensToday'] ?? 0}',
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEngagementSection(AppLocalizations l) {
    final engagement = (_stats?['engagement'] as Map<String, dynamic>?) ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.statsEngagement,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.statsConsecutiveDays,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${engagement['consecutiveLearningDays'] ?? 0} 🔥',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.statsFavoriteScene,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${engagement['favoriteScene'] ?? l.statsNone} ⭐',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSceneProgressSection(AppLocalizations l) {
    final sceneProgress = (_stats?['sceneProgress'] as Map<String, dynamic>?) ?? {};

    if (sceneProgress.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.statsSceneProgress,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...sceneProgress.entries.map((entry) {
          final sceneName = entry.key;
          final data = entry.value as Map<String, dynamic>;
          final messages = data['messages'] as int? ?? 0;
          final tokens = data['tokens'] as int? ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sceneName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.statsMessagesCount(messages)),
                    Text(l.statsTokensCount(tokens)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
