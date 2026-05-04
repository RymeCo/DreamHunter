import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { user, system, announcement }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final String region;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.type = MessageType.user,
    this.region = 'english',
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Dreamer',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'user'),
        orElse: () => MessageType.user,
      ),
      region: data['region'] ?? 'english',
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Dreamer',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'user'),
        orElse: () => MessageType.user,
      ),
      region: json['region'] ?? 'english',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.name,
      'region': region,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': type.name,
      'region': region,
    };
  }
}
