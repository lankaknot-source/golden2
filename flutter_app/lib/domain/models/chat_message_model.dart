import 'package:equatable/equatable.dart';

// Matches care2's chats Firestore collection exactly
class ChatMessage extends Equatable {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl; // base64 encoded image
  final int timestamp; // Unix millis

  const ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageUrl,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      bookingId: map['bookingId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': timestamp,
      };

  @override
  List<Object?> get props => [id, bookingId, senderId, text, timestamp];
}
