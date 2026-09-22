import 'package:equatable/equatable.dart';

// Status values stored uppercase to match care2
enum BookingStatus {
  pending,
  broadcasted,
  broadcastAccepted,
  accepted,
  inProgress,
  completed,
  rejected,
  declined,
  cancelled,
}

extension BookingStatusX on BookingStatus {
  // What is stored in Firestore (matches care2)
  String get firestoreValue {
    switch (this) {
      case BookingStatus.pending:
        return 'PENDING';
      case BookingStatus.broadcasted:
        return 'BROADCASTED';
      case BookingStatus.broadcastAccepted:
        return 'BROADCAST_ACCEPTED';
      case BookingStatus.accepted:
        return 'ACCEPTED';
      case BookingStatus.inProgress:
        return 'IN_PROGRESS';
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.rejected:
        return 'REJECTED';
      case BookingStatus.declined:
        return 'DECLINED';
      case BookingStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static BookingStatus fromString(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'BROADCASTED':
        return BookingStatus.broadcasted;
      case 'BROADCAST_ACCEPTED':
        return BookingStatus.broadcastAccepted;
      case 'ACCEPTED':
        return BookingStatus.accepted;
      case 'IN_PROGRESS':
      case 'ACTIVE':
        return BookingStatus.inProgress;
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'REJECTED':
        return BookingStatus.rejected;
      case 'DECLINED':
        return BookingStatus.declined;
      case 'CANCELLED':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }
}

class TaskProofEntry extends Equatable {
  final String taskName;
  final String photoUrl;
  final int timestamp;

  const TaskProofEntry({
    required this.taskName,
    required this.photoUrl,
    required this.timestamp,
  });

  factory TaskProofEntry.fromMap(Map<String, dynamic> m) => TaskProofEntry(
        taskName: m['taskName'] as String? ?? '',
        photoUrl: m['photoUrl'] as String? ?? '',
        timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'taskName': taskName,
        'photoUrl': photoUrl,
        'timestamp': timestamp,
      };

  @override
  List<Object?> get props => [taskName, photoUrl, timestamp];
}

/// A caregiver who accepted a broadcast job. This mirrors care2's
/// `jobAcceptances` array so the iOS client can participate in the same
/// primary/backup confirmation flow as the Android client.
class JobAcceptance extends Equatable {
  final String caregiverId;
  final int acceptedAt;
  final int acceptanceOrder;
  final bool isPrimary;
  final String confirmationStatus;

  const JobAcceptance({
    required this.caregiverId,
    required this.acceptedAt,
    required this.acceptanceOrder,
    required this.isPrimary,
    this.confirmationStatus = 'PENDING',
  });

  factory JobAcceptance.fromMap(Map<String, dynamic> map) => JobAcceptance(
        caregiverId: map['caregiverId'] as String? ?? '',
        acceptedAt: (map['acceptedAt'] as num?)?.toInt() ?? 0,
        acceptanceOrder: (map['acceptanceOrder'] as num?)?.toInt() ?? 0,
        isPrimary: map['isPrimary'] as bool? ?? false,
        confirmationStatus: map['confirmationStatus'] as String? ?? 'PENDING',
      );

  Map<String, dynamic> toMap() => {
        'caregiverId': caregiverId,
        'acceptedAt': acceptedAt,
        'acceptanceOrder': acceptanceOrder,
        'isPrimary': isPrimary,
        'confirmationStatus': confirmationStatus,
      };

  @override
  List<Object?> get props => [
        caregiverId,
        acceptedAt,
        acceptanceOrder,
        isPrimary,
        confirmationStatus,
      ];
}

class Booking extends Equatable {
  final String id;
  final String clientId;
  final String? caregiverId;
  final String elderId;
  final String address;
  final double locationLat;
  final double locationLng;
  final BookingStatus status;
  final String jobDescription;
  final String careCategory;
  final String serviceType;
  final String durationType;
  final bool isEmergency;
  final bool isSubscriptionBooking;
  final String? planName;
  final List<String> allowedCaregivers;
  final List<String> appliedCaregivers;
  final List<String> rejectedBy;
  final int requestedTime;
  final int scheduledTime;
  final String? startCode;
  final int? startTime;
  final int? endTime;
  final double totalAmount;
  final double hourlyRate;
  final int estimatedHours;
  final bool isPaid;
  final bool isRated;
  final bool isClientEnded;
  final bool isCaregiverAcceptedEnd;
  final List<String> requestedTasks;
  final List<String> completedTasks;
  final List<String> clientApprovedTasks;
  final List<TaskProofEntry> taskProofs;
  final int? acceptedAt; // ms timestamp when caregiver accepted - used for timeout
  final bool hasComplaint;
  final String complaintNotes;
  final String caregiverResponse;
  final bool replacementRequested;
  final String replacementReason;
  final String? pendingConfirmCaregiverId;
  final int? confirmDeadlineMs;
  final double broadcastRadius;
  final List<JobAcceptance> jobAcceptances;

  const Booking({
    required this.id,
    required this.clientId,
    this.caregiverId,
    required this.elderId,
    required this.address,
    required this.locationLat,
    required this.locationLng,
    this.status = BookingStatus.pending,
    this.jobDescription = '',
    this.careCategory = '',
    this.serviceType = '',
    this.durationType = '',
    this.isEmergency = false,
    this.isSubscriptionBooking = false,
    this.planName,
    this.allowedCaregivers = const [],
    this.appliedCaregivers = const [],
    this.rejectedBy = const [],
    required this.requestedTime,
    this.scheduledTime = 0,
    this.startCode,
    this.startTime,
    this.endTime,
    this.totalAmount = 0.0,
    this.hourlyRate = 0.0,
    this.estimatedHours = 0,
    this.isPaid = false,
    this.isRated = false,
    this.isClientEnded = false,
    this.isCaregiverAcceptedEnd = false,
    this.requestedTasks = const [],
    this.completedTasks = const [],
    this.clientApprovedTasks = const [],
    this.taskProofs = const [],
    this.acceptedAt,
    this.hasComplaint = false,
    this.complaintNotes = '',
    this.caregiverResponse = '',
    this.replacementRequested = false,
    this.replacementReason = '',
    this.pendingConfirmCaregiverId,
    this.confirmDeadlineMs,
    this.broadcastRadius = 5.0,
    this.jobAcceptances = const [],
  });

  factory Booking.fromMap(Map<String, dynamic> map, String id) {
    final rawProofs = map['taskProofs'] as List? ?? [];
    final rawAcceptances = map['jobAcceptances'] as List? ?? [];
    return Booking(
      id: id,
      clientId: map['clientId'] as String? ?? '',
      caregiverId: map['caregiverId'] as String?,
      elderId: map['elderId'] as String? ?? '',
      address: map['address'] as String? ?? '',
      locationLat: (map['locationLat'] as num?)?.toDouble() ?? 0.0,
      locationLng: (map['locationLng'] as num?)?.toDouble() ?? 0.0,
      status: BookingStatusX.fromString(map['status'] as String?),
      jobDescription: map['jobDescription'] as String? ?? '',
      careCategory: map['careCategory'] as String? ?? '',
      serviceType: map['serviceType'] as String? ?? '',
      durationType: map['durationType'] as String? ?? '',
      isEmergency: map['isEmergency'] as bool? ?? false,
      isSubscriptionBooking: map['isSubscriptionBooking'] as bool? ?? false,
      planName: map['planName'] as String?,
      allowedCaregivers: List<String>.from(map['allowedCaregivers'] as List? ?? []),
      appliedCaregivers: List<String>.from(map['appliedCaregivers'] as List? ?? []),
      rejectedBy: List<String>.from(map['rejectedBy'] as List? ?? []),
      requestedTime: (map['requestedTime'] as num?)?.toInt() ?? 0,
      scheduledTime: (map['scheduledTime'] as num?)?.toInt() ?? 0,
      startCode: map['startCode'] as String?,
      startTime: (map['startTime'] as num?)?.toInt(),
      endTime: (map['endTime'] as num?)?.toInt(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      estimatedHours: (map['estimatedHours'] as num?)?.toInt() ?? 0,
      isPaid: map['isPaid'] as bool? ?? false,
      isRated: map['isRated'] as bool? ?? false,
      isClientEnded: map['isClientEnded'] as bool? ?? false,
      isCaregiverAcceptedEnd: map['isCaregiverAcceptedEnd'] as bool? ?? false,
      requestedTasks: List<String>.from(map['requestedTasks'] as List? ?? []),
      completedTasks: List<String>.from(map['completedTasks'] as List? ?? []),
      clientApprovedTasks: List<String>.from(map['clientApprovedTasks'] as List? ?? []),
      taskProofs: rawProofs
          .map((e) => TaskProofEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      acceptedAt: (map['acceptedAt'] as num?)?.toInt(),
      hasComplaint: map['hasComplaint'] as bool? ?? false,
      complaintNotes: map['complaintNotes'] as String? ?? '',
      caregiverResponse: map['caregiverResponse'] as String? ?? '',
      replacementRequested: map['replacementRequested'] as bool? ?? false,
      replacementReason: map['replacementReason'] as String? ?? '',
      pendingConfirmCaregiverId: map['pendingConfirmCaregiverId'] as String?,
      confirmDeadlineMs: (map['confirmDeadlineMs'] as num?)?.toInt(),
      broadcastRadius: (map['broadcastRadius'] as num?)?.toDouble() ?? 5.0,
      jobAcceptances: rawAcceptances
          .whereType<Map>()
          .map((e) => JobAcceptance.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'caregiverId': caregiverId,
        'elderId': elderId,
        'address': address,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'status': status.firestoreValue,
        'jobDescription': jobDescription,
        'careCategory': careCategory,
        'serviceType': serviceType,
        'durationType': durationType,
        'isEmergency': isEmergency,
        'isSubscriptionBooking': isSubscriptionBooking,
        'planName': planName,
        'allowedCaregivers': allowedCaregivers,
        'appliedCaregivers': appliedCaregivers,
        'rejectedBy': rejectedBy,
        'requestedTime': requestedTime,
        'scheduledTime': scheduledTime,
        'startCode': startCode,
        'startTime': startTime,
        'endTime': endTime,
        'totalAmount': totalAmount,
        'hourlyRate': hourlyRate,
        'estimatedHours': estimatedHours,
        'isPaid': isPaid,
        'isRated': isRated,
        'isClientEnded': isClientEnded,
        'isCaregiverAcceptedEnd': isCaregiverAcceptedEnd,
        'requestedTasks': requestedTasks,
        'completedTasks': completedTasks,
        'clientApprovedTasks': clientApprovedTasks,
        'taskProofs': taskProofs.map((e) => e.toMap()).toList(),
        'acceptedAt': acceptedAt,
        'hasComplaint': hasComplaint,
        'complaintNotes': complaintNotes,
        'caregiverResponse': caregiverResponse,
        'replacementRequested': replacementRequested,
        'replacementReason': replacementReason,
        'pendingConfirmCaregiverId': pendingConfirmCaregiverId,
        'confirmDeadlineMs': confirmDeadlineMs,
        'broadcastRadius': broadcastRadius,
        'jobAcceptances': jobAcceptances.map((e) => e.toMap()).toList(),
      };

  Booking copyWith({
    String? caregiverId,
    BookingStatus? status,
    String? startCode,
    int? startTime,
    int? endTime,
    int? acceptedAt,
    double? totalAmount,
    double? hourlyRate,
    bool? isPaid,
    bool? isRated,
    bool? isClientEnded,
    bool? isCaregiverAcceptedEnd,
    List<String>? completedTasks,
    List<TaskProofEntry>? taskProofs,
    List<String>? clientApprovedTasks,
    bool? hasComplaint,
    String? complaintNotes,
    String? caregiverResponse,
    bool? replacementRequested,
    String? replacementReason,
    List<String>? rejectedBy,
    List<String>? appliedCaregivers,
    String? pendingConfirmCaregiverId,
    int? confirmDeadlineMs,
    double? broadcastRadius,
    List<JobAcceptance>? jobAcceptances,
  }) =>
      Booking(
        id: id,
        clientId: clientId,
        caregiverId: caregiverId ?? this.caregiverId,
        elderId: elderId,
        address: address,
        locationLat: locationLat,
        locationLng: locationLng,
        status: status ?? this.status,
        jobDescription: jobDescription,
        careCategory: careCategory,
        serviceType: serviceType,
        durationType: durationType,
        isEmergency: isEmergency,
        isSubscriptionBooking: isSubscriptionBooking,
        planName: planName,
        allowedCaregivers: allowedCaregivers,
        appliedCaregivers: appliedCaregivers ?? this.appliedCaregivers,
        rejectedBy: rejectedBy ?? this.rejectedBy,
        requestedTime: requestedTime,
        scheduledTime: scheduledTime,
        startCode: startCode ?? this.startCode,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        totalAmount: totalAmount ?? this.totalAmount,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        estimatedHours: estimatedHours,
        isPaid: isPaid ?? this.isPaid,
        isRated: isRated ?? this.isRated,
        isClientEnded: isClientEnded ?? this.isClientEnded,
        isCaregiverAcceptedEnd: isCaregiverAcceptedEnd ?? this.isCaregiverAcceptedEnd,
        requestedTasks: requestedTasks,
        completedTasks: completedTasks ?? this.completedTasks,
        clientApprovedTasks: clientApprovedTasks ?? this.clientApprovedTasks,
        taskProofs: taskProofs ?? this.taskProofs,
        hasComplaint: hasComplaint ?? this.hasComplaint,
        complaintNotes: complaintNotes ?? this.complaintNotes,
        caregiverResponse: caregiverResponse ?? this.caregiverResponse,
        replacementRequested: replacementRequested ?? this.replacementRequested,
        replacementReason: replacementReason ?? this.replacementReason,
        pendingConfirmCaregiverId:
            pendingConfirmCaregiverId ?? this.pendingConfirmCaregiverId,
        confirmDeadlineMs: confirmDeadlineMs ?? this.confirmDeadlineMs,
        broadcastRadius: broadcastRadius ?? this.broadcastRadius,
        jobAcceptances: jobAcceptances ?? this.jobAcceptances,
      );

  bool get isActive => status == BookingStatus.inProgress;

  // True when ACCEPTED but caregiver has not started within 30 min
  bool get isAcceptanceExpired {
    if (status != BookingStatus.accepted || acceptedAt == null) return false;
    const timeoutMs = 30 * 60 * 1000;
    return DateTime.now().millisecondsSinceEpoch - acceptedAt! > timeoutMs;
  }

  // Duration in hours based on actual start/end times
  double get durationHours {
    if (startTime == null) return estimatedHours.toDouble();
    final end = endTime ?? DateTime.now().millisecondsSinceEpoch;
    return (end - startTime!) / (1000 * 60 * 60);
  }

  // Current earning
  double get currentEarning {
    if (totalAmount > 0) return totalAmount;
    return durationHours * hourlyRate;
  }

  @override
  List<Object?> get props => [
        id, clientId, caregiverId, elderId, address, locationLat, locationLng,
        status, jobDescription, careCategory, isEmergency, requestedTime,
        startCode, startTime, endTime, totalAmount, isPaid, isRated,
        isClientEnded, isCaregiverAcceptedEnd, requestedTasks, completedTasks,
      ];
}
