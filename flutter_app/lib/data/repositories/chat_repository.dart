import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/chat_message_model.dart';

// Matches care2's flat chats Firestore collection with bookingId filter
class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.chatsCollection);

  Future<void> sendMessage(ChatMessage message) async {
    await _col.add(message.toMap());
  }

  Stream<List<ChatMessage>> streamMessages(String bookingId, {int limit = 50}) {
    return _col
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('timestamp')
        .limitToLast(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ChatMessage.fromMap(d.data(), d.id)).toList());
  }

  Future<List<ChatMessage>> getMessages(String bookingId) async {
    final snap = await _col
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('timestamp')
        .get();
    return snap.docs.map((d) => ChatMessage.fromMap(d.data(), d.id)).toList();
  }
}
