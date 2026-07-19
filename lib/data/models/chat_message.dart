import '../../main.dart';

/// A single chat message row from the `messages` table.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime sentAt;

  /// Cached translations keyed by target language code (e.g. `'en'`, `'hi'`).
  /// Stored as JSONB in the `translations` column.
  final Map<String, String> translations;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.sentAt,
    this.translations = const {},
  });

  /// True when this message was sent by the currently signed-in user.
  bool get isMe => senderId == supabase.auth.currentUser?.id;

  factory ChatMessage.fromMap(Map<String, dynamic> m) {
    final raw = m['translations'];
    final translations = raw is Map<String, dynamic>
        ? raw.map((k, v) => MapEntry(k, v as String))
        : <String, String>{};
    return ChatMessage(
      id: m['id'] as String,
      senderId: m['sender_id'] as String,
      senderName: m['sender_name'] as String? ?? '',
      content: m['content'] as String? ?? '',
      sentAt: DateTime.parse(m['sent_at'] as String),
      translations: translations,
    );
  }
}
