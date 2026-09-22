import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/wallet_repository.dart';
import '../../domain/models/wallet_transaction_model.dart';
import 'auth_provider.dart';

final walletRepositoryProvider =
    Provider<WalletRepository>((_) => WalletRepository());

final transactionsProvider = StreamProvider<List<WalletTransaction>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(walletRepositoryProvider).streamTransactions(user.uid);
});

class WalletNotifier extends StateNotifier<AsyncValue<void>> {
  final WalletRepository _repo;
  WalletNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> createTransaction(WalletTransaction tx) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createTransaction(tx);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> topUp({
    required String userId,
    required double amount,
    required String description,
    String? receiptBase64,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.topUpWallet(
        userId: userId,
        amount: amount,
        description: description,
        receiptBase64: receiptBase64,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final walletNotifierProvider =
    StateNotifierProvider<WalletNotifier, AsyncValue<void>>(
  (ref) => WalletNotifier(ref.watch(walletRepositoryProvider)),
);
