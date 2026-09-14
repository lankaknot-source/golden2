import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/data_models.dart';

class ChatViewModel extends ChangeNotifier {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  String get currentUserId => _auth.currentUser?.uid ?? "";
  String _currentUserName = "User";
  String get currentUserName => _currentUserName;

  ChatViewModel() {
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    if (currentUserId.isNotEmpty) {
      try {
        final doc = await _firestore.collection("users").doc(currentUserId).get();
        if (doc.exists) {
          _currentUserName = doc.data()?['name'] ?? "User";
          notifyListeners();
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  void loadMessages(String bookingId) {
    _firestore.collection("chats")
        .where("bookingId", isEqualTo: bookingId)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first for ListView.builder reversed
      _messages = list;
      notifyListeners();
    });
  }

  Future<void> sendMessage(String bookingId, String text, {String? imageUrl}) async {
    if (text.trim().isEmpty && (imageUrl == null || imageUrl.isEmpty)) return;
    
    final msgId = const Uuid().v4();
    final chatMsg = ChatMessage(
      id: msgId,
      bookingId: bookingId,
      senderId: currentUserId,
      senderName: _currentUserName,
      text: text.trim(),
      imageUrl: imageUrl ?? "",
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await _firestore.collection("chats").doc(msgId).set(chatMsg.toMap());
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
