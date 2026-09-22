import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/wallet_transaction_model.dart';

class WalletRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Uses 'transactions' collection to match care2
  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.transactionsCollection);

  Stream<List<WalletTransaction>> streamTransactions(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => WalletTransaction.fromMap(d.data(), d.id)).toList());
  }

  Future<String> createTransaction(WalletTransaction tx) async {
    final ref = await _col.add(tx.toMap());
    return ref.id;
  }

  Future<void> updateReceiptImage(String txId, String base64Image) =>
      _col.doc(txId).update({'receiptImageUrl': base64Image});

  // Top up wallet: creates a FEE transaction + updates user's walletBalance
  Future<void> topUpWallet({
    required String userId,
    required double amount,
    required String description,
    String? receiptBase64,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _col.add({
      'userId': userId,
      'type': 'CREDIT',
      'amount': amount,
      'description': description,
      'timestamp': now,
      'receiptImageUrl': receiptBase64,
    });
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'walletBalance': FieldValue.increment(amount)});
  }
}
