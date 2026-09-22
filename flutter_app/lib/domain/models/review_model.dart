import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// Matches care2's reviews collection
class Review extends Equatable {
  final String id;
  final String bookingId;
  final String clientId;
  final String caregiverId;
  final double rating;
  final String comment;
  final int timestamp; // Unix millis (matches care2)

  const Review({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.caregiverId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    int parseTimestamp(dynamic raw) {
      if (raw is num) return raw.toInt();
      if (raw is Timestamp) return raw.toDate().millisecondsSinceEpoch;
      return DateTime.now().millisecondsSinceEpoch;
    }

    return Review(
      id: id,
      bookingId: map['bookingId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      caregiverId: map['caregiverId'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'] as String? ?? '',
      timestamp: parseTimestamp(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'clientId': clientId,
        'caregiverId': caregiverId,
        'rating': rating,
        'comment': comment,
        'timestamp': timestamp,
      };

  @override
  List<Object?> get props => [id, bookingId, clientId, caregiverId, rating, comment, timestamp];
}
