import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class TaskProof extends Equatable {
  final String id;
  final String bookingId;
  final String caregiverId;
  final String taskDescription;
  final List<String> photoUrls;
  final String notes;
  final DateTime submittedAt;
  final bool isVerified;

  const TaskProof({
    required this.id,
    required this.bookingId,
    required this.caregiverId,
    required this.taskDescription,
    this.photoUrls = const [],
    this.notes = '',
    required this.submittedAt,
    this.isVerified = false,
  });

  factory TaskProof.fromMap(Map<String, dynamic> map, String id) {
    return TaskProof(
      id: id,
      bookingId: map['bookingId'] as String? ?? '',
      caregiverId: map['caregiverId'] as String? ?? '',
      taskDescription: map['taskDescription'] as String? ?? '',
      photoUrls: List<String>.from(map['photoUrls'] as List? ?? []),
      notes: map['notes'] as String? ?? '',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'caregiverId': caregiverId,
        'taskDescription': taskDescription,
        'photoUrls': photoUrls,
        'notes': notes,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'isVerified': isVerified,
      };

  TaskProof copyWith({
    List<String>? photoUrls,
    String? notes,
    bool? isVerified,
  }) =>
      TaskProof(
        id: id,
        bookingId: bookingId,
        caregiverId: caregiverId,
        taskDescription: taskDescription,
        photoUrls: photoUrls ?? this.photoUrls,
        notes: notes ?? this.notes,
        submittedAt: submittedAt,
        isVerified: isVerified ?? this.isVerified,
      );

  @override
  List<Object?> get props => [
        id, bookingId, caregiverId, taskDescription,
        photoUrls, notes, submittedAt, isVerified,
      ];
}
