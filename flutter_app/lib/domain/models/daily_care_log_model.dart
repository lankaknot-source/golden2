import 'package:equatable/equatable.dart';

// Matches care2's care_logs Firestore collection
class DailyCareLog extends Equatable {
  final String id;
  final String bookingId;
  final String caregiverId;
  final String elderId;
  final int timestamp; // Unix millis (matches care2)
  final String bloodPressure;
  final String sugarLevel;
  final String temperature;
  final String mealStatus;
  final bool medicationGiven;
  final String notes;

  const DailyCareLog({
    required this.id,
    required this.bookingId,
    required this.caregiverId,
    required this.elderId,
    required this.timestamp,
    this.bloodPressure = '',
    this.sugarLevel = '',
    this.temperature = '',
    this.mealStatus = '',
    this.medicationGiven = false,
    this.notes = '',
  });

  factory DailyCareLog.fromMap(Map<String, dynamic> map, String id) {
    return DailyCareLog(
      id: id,
      bookingId: map['bookingId'] as String? ?? '',
      caregiverId: map['caregiverId'] as String? ?? '',
      elderId: map['elderId'] as String? ?? map['elderProfileId'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      bloodPressure: map['bloodPressure'] as String? ?? '',
      sugarLevel: map['sugarLevel'] as String? ?? '',
      temperature: map['temperature'] as String? ?? '',
      mealStatus: map['mealStatus'] as String? ?? '',
      medicationGiven: map['medicationGiven'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'caregiverId': caregiverId,
        'elderId': elderId,
        'timestamp': timestamp,
        'bloodPressure': bloodPressure,
        'sugarLevel': sugarLevel,
        'temperature': temperature,
        'mealStatus': mealStatus,
        'medicationGiven': medicationGiven,
        'notes': notes,
      };

  DailyCareLog copyWith({
    String? bloodPressure,
    String? sugarLevel,
    String? temperature,
    String? mealStatus,
    bool? medicationGiven,
    String? notes,
  }) =>
      DailyCareLog(
        id: id,
        bookingId: bookingId,
        caregiverId: caregiverId,
        elderId: elderId,
        timestamp: timestamp,
        bloodPressure: bloodPressure ?? this.bloodPressure,
        sugarLevel: sugarLevel ?? this.sugarLevel,
        temperature: temperature ?? this.temperature,
        mealStatus: mealStatus ?? this.mealStatus,
        medicationGiven: medicationGiven ?? this.medicationGiven,
        notes: notes ?? this.notes,
      );

  @override
  List<Object?> get props => [
        id, bookingId, caregiverId, elderId, timestamp,
        bloodPressure, sugarLevel, temperature, mealStatus, medicationGiven, notes,
      ];
}
