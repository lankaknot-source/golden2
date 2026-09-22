import 'package:equatable/equatable.dart';

// Matches care2's MedicineReminder with photoBase64
class MedicineReminder {
  final String id;
  final String time; // HH:mm
  final String name;
  final String photoBase64;

  const MedicineReminder({
    required this.id,
    required this.time,
    required this.name,
    this.photoBase64 = '',
  });

  factory MedicineReminder.fromMap(Map<String, dynamic> m) => MedicineReminder(
        id: m['id'] as String? ?? '',
        time: m['time'] as String? ?? '',
        name: m['name'] as String? ?? '',
        photoBase64: m['photoBase64'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'time': time,
        'name': name,
        'photoBase64': photoBase64,
      };
}

// Matches care2's ElderProfile exactly
// Collection: 'elders'
class ElderProfile extends Equatable {
  final String id;
  final String clientId;
  final String name;
  final int age;
  final String gender;
  final List<String> medicalConditions;
  final String specialCareRequirements;
  final String emergencyContactPerson;
  final String emergencyContact;
  final String requiredLanguage;
  final List<MedicineReminder> medicineList;

  const ElderProfile({
    required this.id,
    required this.clientId,
    required this.name,
    required this.age,
    required this.gender,
    this.medicalConditions = const [],
    this.specialCareRequirements = '',
    this.emergencyContactPerson = '',
    required this.emergencyContact,
    this.requiredLanguage = 'Sinhala',
    this.medicineList = const [],
  });

  factory ElderProfile.fromMap(Map<String, dynamic> map, String id) {
    // medicalConditions can be List<String> or String (backward compat)
    List<String> parseMedicalConditions(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return List<String>.from(raw);
      if (raw is String && raw.isNotEmpty) return [raw];
      return [];
    }

    return ElderProfile(
      id: id,
      clientId: map['clientId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      gender: map['gender'] as String? ?? '',
      medicalConditions: parseMedicalConditions(map['medicalConditions']),
      specialCareRequirements: map['specialCareRequirements'] as String? ?? '',
      emergencyContactPerson: map['emergencyContactPerson'] as String? ?? '',
      emergencyContact: map['emergencyContact'] as String? ?? '',
      requiredLanguage: map['requiredLanguage'] as String? ?? 'Sinhala',
      medicineList: (map['medicineList'] as List? ?? [])
          .map((e) => MedicineReminder.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'name': name,
        'age': age,
        'gender': gender,
        'medicalConditions': medicalConditions,
        'specialCareRequirements': specialCareRequirements,
        'emergencyContactPerson': emergencyContactPerson,
        'emergencyContact': emergencyContact,
        'requiredLanguage': requiredLanguage,
        'medicineList': medicineList.map((r) => r.toMap()).toList(),
      };

  ElderProfile copyWith({
    String? name,
    int? age,
    String? gender,
    List<String>? medicalConditions,
    String? specialCareRequirements,
    String? emergencyContactPerson,
    String? emergencyContact,
    String? requiredLanguage,
    List<MedicineReminder>? medicineList,
  }) =>
      ElderProfile(
        id: id,
        clientId: clientId,
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        medicalConditions: medicalConditions ?? this.medicalConditions,
        specialCareRequirements: specialCareRequirements ?? this.specialCareRequirements,
        emergencyContactPerson: emergencyContactPerson ?? this.emergencyContactPerson,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        requiredLanguage: requiredLanguage ?? this.requiredLanguage,
        medicineList: medicineList ?? this.medicineList,
      );

  @override
  List<Object?> get props => [
        id, clientId, name, age, gender, medicalConditions,
        specialCareRequirements, emergencyContact, requiredLanguage, medicineList,
      ];
}
