import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum LeaveStatus { pending, approved, rejected }

class LeaveRequest extends Equatable {
  final String id;
  final String caregiverId;
  final String bookingId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;
  final String? adminNote;
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.caregiverId,
    required this.bookingId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = LeaveStatus.pending,
    this.adminNote,
    required this.createdAt,
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map, String id) {
    return LeaveRequest(
      id: id,
      caregiverId: map['caregiverId'] as String? ?? '',
      bookingId: map['bookingId'] as String? ?? '',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: map['reason'] as String? ?? '',
      status: LeaveStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => LeaveStatus.pending,
      ),
      adminNote: map['adminNote'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'caregiverId': caregiverId,
        'bookingId': bookingId,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'reason': reason,
        'status': status.name,
        'adminNote': adminNote,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  LeaveRequest copyWith({LeaveStatus? status, String? adminNote}) =>
      LeaveRequest(
        id: id,
        caregiverId: caregiverId,
        bookingId: bookingId,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        status: status ?? this.status,
        adminNote: adminNote ?? this.adminNote,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id, caregiverId, bookingId, startDate, endDate,
        reason, status, adminNote, createdAt,
      ];
}
