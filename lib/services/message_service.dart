import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';
import 'package:uuid/uuid.dart';

/// Service for managing messages in Supabase.
/// 
/// Handles:
/// - Saving user messages
/// - Saving assistant responses
/// - Loading message history
/// - Managing conversation sessions
class MessageService {
  final SupabaseClient _supabase;

  MessageService(this._supabase);

  /// Get singleton instance (initialized in main.dart)
  static MessageService? _instance;

  static MessageService getInstance(SupabaseClient supabase) {
    _instance ??= MessageService(supabase);
    return _instance!;
  }

  /// Save a message to Supabase
  /// 
  /// Returns the saved Message object with ID
  /// Throws SupabaseException on failure
  Future<Message> saveMessage({
    required String userId,
    required String sceneId,
    required String role,
    required String content,
    int? tokensUsed,
  }) async {
    try {
      final messageId = const Uuid().v4();
      final now = DateTime.now().toUtc();

      final message = Message(
        id: messageId,
        userId: userId,
        sceneId: sceneId,
        role: role,
        content: content,
        tokensUsed: tokensUsed,
        createdAt: now,
      );

      await _supabase
          .from('messages')
          .insert(message.toJson())
          .then((response) {
        // RLS policy will reject if user_id doesn't match auth.uid()
      });

      // Update conversation session stats
      await _updateSessionStats(userId, sceneId, tokensUsed ?? 0);

      return message;
    } on PostgrestException catch (e) {
      throw Exception('Failed to save message: ${e.message}');
    }
  }

  /// Load message history for a specific scene
  /// 
  /// Returns list of messages in chronological order
  Future<List<Message>> loadMessageHistory({
    required String userId,
    required String sceneId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('user_id', userId)
          .eq('scene_id', sceneId)
          .order('created_at', ascending: true)
          .limit(limit);

      final messages = (response as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();

      return messages;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load message history: ${e.message}');
    }
  }

  /// Load recent messages (last N for chat display)
  Future<List<Message>> loadRecentMessages({
    required String userId,
    required String sceneId,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('user_id', userId)
          .eq('scene_id', sceneId)
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = (response as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();

      // Reverse to chronological order for display
      return messages.reversed.toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load recent messages: ${e.message}');
    }
  }

  /// Get or create a conversation session
  Future<ConversationSession> getOrCreateSession({
    required String userId,
    required String sceneId,
  }) async {
    try {
      // Try to find existing session
      final existing = await _supabase
          .from('conversation_sessions')
          .select()
          .eq('user_id', userId)
          .eq('scene_id', sceneId)
          .eq('status', 'active')
          .maybeSingle();

      if (existing != null) {
        return ConversationSession.fromJson(existing);
      }

      // Create new session
      final sessionId = const Uuid().v4();
      final now = DateTime.now().toUtc();

      final session = ConversationSession(
        id: sessionId,
        userId: userId,
        sceneId: sceneId,
        totalMessages: 0,
        totalTokensUsed: 0,
        lastMessageAt: null,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      await _supabase.from('conversation_sessions').insert(session.toJson());

      return session;
    } on PostgrestException catch (e) {
      throw Exception('Failed to manage conversation session: ${e.message}');
    }
  }

  /// Update session stats after message save
  /// (called internally by saveMessage)
  Future<void> _updateSessionStats(
    String userId,
    String sceneId,
    int tokensUsed,
  ) async {
    try {
      final now = DateTime.now().toUtc();

      await _supabase.from('conversation_sessions').update({
        'total_messages': 'total_messages + 1',
        'total_tokens_used': 'total_tokens_used + $tokensUsed',
        'last_message_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('user_id', userId).eq('scene_id', sceneId).eq('status', 'active');
    } catch (e) {
      // Non-critical: log but don't crash
      print('Warning: Failed to update session stats: $e');
    }
  }

  /// Close/complete a conversation session
  Future<void> closeSession({
    required String userId,
    required String sceneId,
    String status = 'completed',
  }) async {
    try {
      await _supabase.from('conversation_sessions').update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId).eq('scene_id', sceneId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to close session: ${e.message}');
    }
  }

  /// Delete all messages in a session (for reset)
  Future<void> clearSessionMessages({
    required String userId,
    required String sceneId,
  }) async {
    try {
      await _supabase.from('messages').delete().eq('user_id', userId).eq('scene_id', sceneId);

      // Reset session stats
      await _supabase.from('conversation_sessions').update({
        'total_messages': 0,
        'total_tokens_used': 0,
        'last_message_at': null,
      }).eq('user_id', userId).eq('scene_id', sceneId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to clear session: ${e.message}');
    }
  }

  /// Get user's all sessions (for session history)
  Future<List<ConversationSession>> getUserSessions(String userId) async {
    try {
      final response = await _supabase
          .from('conversation_sessions')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => ConversationSession.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load user sessions: ${e.message}');
    }
  }
}
