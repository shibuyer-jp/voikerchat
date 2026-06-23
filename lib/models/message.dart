import 'package:intl/intl.dart';

/// Represents a chat message in Voikerchat.
/// 
/// Roles:
/// - 'user': Message from the learner
/// - 'assistant': Response from Claude Haiku
class Message {
  final String id;
  final String userId;
  final String sceneId;
  final String role; // 'user' | 'assistant'
  final String content;
  final int? tokensUsed;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.userId,
    required this.sceneId,
    required this.role,
    required this.content,
    this.tokensUsed,
    required this.createdAt,
  });

  /// Convert to JSON for Supabase storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'scene_id': sceneId,
      'role': role,
      'content': content,
      'tokens_used': tokensUsed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Parse from Supabase database row
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sceneId: json['scene_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      tokensUsed: json['tokens_used'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Create a copy with modified fields
  Message copyWith({
    String? id,
    String? userId,
    String? sceneId,
    String? role,
    String? content,
    int? tokensUsed,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sceneId: sceneId ?? this.sceneId,
      role: role ?? this.role,
      content: content ?? this.content,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Human-readable timestamp (JST)
  String get formattedTime {
    final jst = createdAt.add(const Duration(hours: 9));
    return DateFormat('HH:mm').format(jst);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Message(id: $id, role: $role, content: ${content.substring(0, 20)}...)';
}

/// Represents a conversation session (multiple messages in one scene)
class ConversationSession {
  final String id;
  final String userId;
  final String sceneId;
  final int totalMessages;
  final int totalTokensUsed;
  final DateTime? lastMessageAt;
  final String status; // 'active' | 'completed' | 'abandoned'
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationSession({
    required this.id,
    required this.userId,
    required this.sceneId,
    required this.totalMessages,
    required this.totalTokensUsed,
    this.lastMessageAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'scene_id': sceneId,
      'total_messages': totalMessages,
      'total_tokens_used': totalTokensUsed,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ConversationSession.fromJson(Map<String, dynamic> json) {
    return ConversationSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sceneId: json['scene_id'] as String,
      totalMessages: json['total_messages'] as int,
      totalTokensUsed: json['total_tokens_used'] as int,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  ConversationSession copyWith({
    String? id,
    String? userId,
    String? sceneId,
    int? totalMessages,
    int? totalTokensUsed,
    DateTime? lastMessageAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sceneId: sceneId ?? this.sceneId,
      totalMessages: totalMessages ?? this.totalMessages,
      totalTokensUsed: totalTokensUsed ?? this.totalTokensUsed,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ConversationSession(id: $id, messages: $totalMessages, status: $status)';
}
