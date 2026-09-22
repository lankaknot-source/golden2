import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/chat_repository.dart';
import '../../domain/models/chat_message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((_) => ChatRepository());

// Messages are streamed by bookingId (matches care2)
final messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, bookingId) {
  return ref.watch(chatRepositoryProvider).streamMessages(bookingId);
});

class ChatNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repo;
  ChatNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> sendMessage(ChatMessage message) async {
    try {
      await _repo.sendMessage(message);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<void>>(
  (ref) => ChatNotifier(ref.watch(chatRepositoryProvider)),
);
