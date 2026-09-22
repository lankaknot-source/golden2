import 'package:equatable/equatable.dart';

// Type values match care2 exactly (uppercase)
enum TransactionType { credit, debit, fee }

class WalletTransaction extends Equatable {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String description;
  final int timestamp; // Unix millis (matches care2)
  final String? receiptImageUrl; // base64 payment slip

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.receiptImageUrl,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: _parseType(map['type'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      receiptImageUrl: map['receiptImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': _typeToString(type),
        'amount': amount,
        'description': description,
        'timestamp': timestamp,
        'receiptImageUrl': receiptImageUrl,
      };

  static TransactionType _parseType(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'DEBIT':
        return TransactionType.debit;
      case 'FEE':
      case 'PACKAGE_FEE':
        return TransactionType.fee;
      default:
        return TransactionType.credit;
    }
  }

  static String _typeToString(TransactionType t) {
    switch (t) {
      case TransactionType.debit:
        return 'DEBIT';
      case TransactionType.fee:
        return 'FEE';
      case TransactionType.credit:
        return 'CREDIT';
    }
  }

  bool get isCredit => type == TransactionType.credit;

  WalletTransaction copyWith({String? receiptImageUrl}) => WalletTransaction(
        id: id,
        userId: userId,
        type: type,
        amount: amount,
        description: description,
        timestamp: timestamp,
        receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      );

  @override
  List<Object?> get props => [id, userId, type, amount, description, timestamp];
}
