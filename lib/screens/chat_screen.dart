import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';
import '../models/rate_limit.dart';
import '../services/message_service.dart';
import '../services/rate_limit_service.dart';

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
  late TextEditingController _inputController;
  late ScrollController _scrollController;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _userId;
  RateLimit? _rateLimit;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();

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

      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Failed to initialize chat: $e');
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

  /// Call Claude Haiku API endpoint
  /// Implementation depends on backend (Firebase Functions, Vercel, or direct)
  Future<Map<String, dynamic>> _callClaudeHaikuAPI({
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> sceneData,
  }) async {
    try {
      // Get Auth token for secure API call
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('No auth token');

      // TODO: Replace with actual backend endpoint
      // For now, return mock response (implement in T-12b proper backend)
      final response = {
        'content': 'これはテスト応答です。実装はバックエンド統合時に更新します。',
        'tokens_used': 150,
      };

      return response;
    } catch (e) {
      throw Exception('Failed to call Claude Haiku API: $e');
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
              // TODO: Navigate to premium purchase flow
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
