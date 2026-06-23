import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/message.dart';
import '../models/rate_limit.dart';
import '../services/message_service.dart';
import '../services/rate_limit_service.dart';
import '../services/revenuecat_service.dart';
import '../widgets/rate_limit_widget.dart';

/// Chat screen for Voikerchat
/// 
/// Displays conversation with Claude Haiku and saves history to Supabase
class ChatScreen extends StatefulWidget {
  final String sceneId;
  final String sceneName;
  final Map<String, dynamic> sceneData;

  const ChatScreen({
    Key? key,
    required this.sceneId,
    required this.sceneName,
    required this.sceneData,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late MessageService _messageService;
  late RateLimitService _rateLimitService;
  late RevenueCatService _revenueCatService;
  late TextEditingController _inputController;
  late ScrollController _scrollController;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _userId;
  RateLimit? _rateLimit;
  bool _isPremium = false;
  bool _showPremiumPromo = true;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    _revenueCatService = RevenueCatService();

    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      _userId = user.id;
      _messageService = MessageService.getInstance(Supabase.instance.client);
      _rateLimitService = RateLimitService(Supabase.instance.client);

      // Get or create session
      await _messageService.getOrCreateSession(
        userId: _userId!,
        sceneId: widget.sceneId,
      );

      // Load existing messages and rate limit status
      await _loadMessages();
      await _loadRateLimit();
      
      // Premium ステータス確認
      await _checkPremiumStatus();

      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Failed to initialize chat: $e');
    }
  }

  Future<void> _checkPremiumStatus() async {
    try {
      _isPremium = await _revenueCatService.checkPremiumStatus();
      setState(() {});
    } catch (e) {
      print('Error checking premium status: $e');
    }
  }

  Future<void> _loadRateLimit() async {
    if (_userId == null) return;
    try {
      final rateLimit = await _rateLimitService.getRateLimit(_userId!);
      setState(() => _rateLimit = rateLimit);
    } catch (e) {
      print('Failed to load rate limit: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (_userId == null) return;

    try {
      final messages = await _messageService.loadMessageHistory(
        userId: _userId!,
        sceneId: widget.sceneId,
      );

      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to load messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Check rate limit before sending
    if (_rateLimit != null && !_rateLimit!.canMakeCall) {
      _showRateLimitDialog();
      return;
    }

    setState(() => _isSending = true);
    _inputController.clear();

    try {
      // Save user message
      final userMessage = await _messageService.saveMessage(
        userId: _userId!,
        sceneId: widget.sceneId,
        role: 'user',
        content: text,
      );

      setState(() => _messages.add(userMessage));
      _scrollToBottom();

      // Get assistant response (Claude Haiku API)
      final assistantResponse = await _getAssistantResponse(text);

      // Save assistant message
      final assistantMessage = await _messageService.saveMessage(
        userId: _userId!,
        sceneId: widget.sceneId,
        role: 'assistant',
        content: assistantResponse['content'],
        tokensUsed: assistantResponse['tokens_used'],
      );

      setState(() => _messages.add(assistantMessage));
      _scrollToBottom();

      // Increment rate limit counter
      await _rateLimitService.checkAndIncrement(_userId!);
      await _loadRateLimit(); // Refresh display

    } catch (e) {
      _showError('Failed to send message: $e');
      // Re-insert user input on error
      _inputController.text = text;
    } finally {
      setState(() => _isSending = false);
    }
  }

  /// Call Claude Haiku API for response
  /// Returns map with 'content' and 'tokens_used'
  Future<Map<String, dynamic>> _getAssistantResponse(String userMessage) async {
    try {
      // Build conversation context from stored messages
      final conversationHistory = _messages
          .map((msg) => {
            'role': msg.role,
            'content': msg.content,
          })
          .toList();

      // Add current message
      conversationHistory.add({
        'role': 'user',
        'content': userMessage,
      });

      // Call Claude Haiku API (via Firebase Functions or Vercel)
      // This assumes T-12b already implemented the backend
      final response = await _callClaudeHaikuAPI(
        messages: conversationHistory,
        sceneData: widget.sceneData,
      );

      return response;
    } catch (e) {
      throw Exception('Assistant API error: $e');
    }
  }

  /// Call Claude Haiku API endpoint (via Vercel /api/chat)
  /// Server-side rate limiting enforced
  Future<Map<String, dynamic>> _callClaudeHaikuAPI({
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> sceneData,
  }) async {
    try {
      // Get Auth token for secure API call
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('No auth token');

      // Call server-side API endpoint with server-side rate limiting
      const baseUrl = 'https://voikerchat.com';
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'messages': messages,
          'sceneId': widget.sceneId,
          'maxTokens': 500,
        }),
      );

      if (response.statusCode == 429) {
        // Rate limit reached - trigger upgrade dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPremiumDialog();
        });
        throw Exception('Daily limit reached. Upgrade to Premium!');
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'API error: ${response.statusCode}');
      }

      final result = jsonDecode(response.body);
      return {
        'content': result['content'] ?? '',
        'tokens_used': result['tokensUsed'] ?? 150,
      };
    } catch (e) {
      throw Exception('Assistant API error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sceneName),
            Text(
              'Level ${widget.sceneData['level'] ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (!_isPremium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showPremiumDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pro',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showSessionOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet\nStart the conversation!',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isUser = message.role == 'user';

                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.only(
                                  bottom: 12,
                                  left: isUser ? 60 : 0,
                                  right: isUser ? 0 : 60,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.content,
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message.formattedTime,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isUser
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Rate limit status + Message input
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rate Limit Widget
                    RateLimitWidget(
                      rateLimit: _rateLimit,
                      onUpgradePressed: () {
                        // TODO: Navigate to Premium purchase flow
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Premium upgrade feature coming soon!'),
                          ),
                        );
                      },
                    ),
                    // Message input
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              decoration: InputDecoration(
                                hintText: 'Type your response...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                enabled: !_isSending,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _isSending ? null : _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _showSessionOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Clear conversation'),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear conversation?'),
                    content: const Text(
                        'This will delete all messages in this session.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && _userId != null) {
                  await _messageService.clearSessionMessages(
                    userId: _userId!,
                    sceneId: widget.sceneId,
                  );
                  setState(() => _messages.clear());
                }
              },
            ),
            ListTile(
              title: const Text('Exit conversation'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRateLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have used all your free daily calls.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_rateLimit != null)
              Text(
                'Limit: ${_rateLimit!.dailyLimit} calls/day',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            const Text(
              '✨ Go Premium to unlock unlimited calls!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPremiumDialog();
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🌟 Voikerchat Premium'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock unlimited conversations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _PremiumFeature(
              icon: '🚀',
              title: 'Unlimited Calls',
              description: 'No daily limits, talk as much as you want',
            ),
            const SizedBox(height: 12),
            _PremiumFeature(
              icon: '✨',
              title: 'Anime Scenes',
              description: '13 engaging scenes to master Japanese',
            ),
            const SizedBox(height: 12),
            _PremiumFeature(
              icon: '📊',
              title: 'Stats Dashboard',
              description: 'Track your learning progress',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_offer, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '\$12.99/month',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _purchasePremium();
            },
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePremium() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing purchase...'),
          ],
        ),
      ),
    );

    try {
      final result = await _revenueCatService.purchasePremium();
      
      Navigator.pop(context); // Close loading dialog
      
      if (result['success'] == true) {
        setState(() => _isPremium = true);
        _showSuccess('✨ Welcome to Premium! Enjoy unlimited conversations!');
      } else {
        // エラーハンドリング
        final errorCode = result['error'] as String?;
        final message = result['message'] as String? ?? 'Purchase failed';
        final retryable = result['retryable'] as bool? ?? false;
        final userInitiated = result['userInitiated'] as bool? ?? false;

        if (userInitiated) {
          // ユーザーがキャンセルした場合
          print('Purchase cancelled by user');
          return;
        }

        if (retryable) {
          _showRetryDialog(message, () => _purchasePremium());
        } else {
          _showErrorWithAction(
            message,
            actionLabel: 'Close',
            onAction: () => Navigator.pop(context),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showError('Unexpected error: $e. Please try again later.');
    }
  }

  /// リトライ可能なエラーダイアログ
  void _showRetryDialog(String message, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Purchase Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// アクション付きエラーダイアログ
  void _showErrorWithAction(
    String message, {
    String actionLabel = 'OK',
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: onAction ?? () => Navigator.pop(context),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// Premium 機能表示用ウィジェット
class _PremiumFeature extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

