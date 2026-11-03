class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.senderName = '',
  });

  final int id;
  final int senderId;
  final String senderRole;
  final String content;
  final String createdAt;
  final String senderName;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: _toInt(json['id']),
    senderId: _toInt(json['sender_id']),
    senderRole: json['sender_role']?.toString() ?? 'customer',
    content: json['content']?.toString() ?? '',
    createdAt: json['created_at']?.toString() ?? '',
    senderName: json['sender_name']?.toString() ?? '',
  );
}

int _toInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
