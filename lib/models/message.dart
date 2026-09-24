import 'package:starlitfilms/models/profile.dart';

class Message {
  final int id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final read = json['read_at'] as String?;
    return Message(
      id: json['id'] as int,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: read == null ? null : DateTime.parse(read),
    );
  }
}

/// Uma linha da lista de conversas: o amigo + a última mensagem trocada.
class Conversation {
  final Profile friend;
  final String? lastContent;
  final DateTime? lastAt;
  final String? lastSenderId;
  final DateTime? lastReadAt;
  final int unread;

  const Conversation({
    required this.friend,
    this.lastContent,
    this.lastAt,
    this.lastSenderId,
    this.lastReadAt,
    this.unread = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    DateTime? date(String k) => json[k] == null ? null : DateTime.parse(json[k] as String);
    return Conversation(
      friend: Profile(
        id: json['friend_id'] as String,
        username: json['username'] as String? ?? '',
        name: json['name'] as String? ?? '',
        bio: '',
        avatarUrl: json['avatar_url'] as String?,
      ),
      lastContent: json['last_content'] as String?,
      lastAt: date('last_at'),
      lastSenderId: json['last_sender'] as String?,
      lastReadAt: date('last_read_at'),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }
}
