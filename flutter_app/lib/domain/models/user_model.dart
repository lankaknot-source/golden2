import 'package:equatable/equatable.dart';

// Must match care2 role strings exactly
enum UserRole { client, caregiver, nurse }

// Must match care2 KYC status strings exactly
enum KycStatus { pending, approved, rejected }

class UserModel extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? profileImageUrl;
  final UserRole role;
  final KycStatus kycStatus;
  final bool isVerified;
  final bool isBusy;
  final double rating;
  final int reviewCount;
  final String? fcmToken;
  final double walletBalance;
  final double? hourlyRate;
  final List<String> favoriteCaregivers;
  final List<String> onLeaveDates;
  // KYC meeting
  final int? kycMeetingDateMs;
  final String? kycMeetingUrl;
  final String? kycMeetingStatus;
  final String? rejectionReason;
  // Location
  final double? locationLat;
  final double? locationLng;

  // KYC personal fields
  final String? nicNumber;
  final String? dob;
  final String? gender;
  final String? address;

  // KYC document URLs (base64 or URLs)
  final String? nicFrontUrl;
  final String? nicBackUrl;
  final String? selfieUrl;
  final String? digitalSignatureUrl;
  final String? policeClearanceUrl;
  final String? medicalFitnessUrl;
  final List<String> certificatesUrls;
  final String? certificateUrl;

  // Professional
  final String? experienceYears;
  final String? specialSkills;
  final String? qualifications;
  final String? references;
  final List<String> categories;
  final String? vaccinationStatus;
  final String? chronicIllnesses;

  // Bank / financial
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankBranch;
  final String? bankBookUrl;
  final double? expectedSalary;

  // Preferences
  final List<String> preferredDistricts;
  final List<String> preferredServiceTypes;

  // Client-specific
  final String? serviceAddress;
  final String? billingName;
  final String? billingAddress;
  final bool autoPaymentConsent;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImageUrl,
    required this.role,
    this.kycStatus = KycStatus.pending,
    this.isVerified = false,
    this.isBusy = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.fcmToken,
    this.walletBalance = 0.0,
    this.hourlyRate,
    this.favoriteCaregivers = const [],
    this.onLeaveDates = const [],
    this.kycMeetingDateMs,
    this.kycMeetingUrl,
    this.kycMeetingStatus,
    this.rejectionReason,
    this.locationLat,
    this.locationLng,
    this.nicNumber,
    this.dob,
    this.gender,
    this.address,
    this.nicFrontUrl,
    this.nicBackUrl,
    this.selfieUrl,
    this.digitalSignatureUrl,
    this.policeClearanceUrl,
    this.medicalFitnessUrl,
    this.certificatesUrls = const [],
    this.certificateUrl,
    this.experienceYears,
    this.specialSkills,
    this.qualifications,
    this.references,
    this.categories = const [],
    this.vaccinationStatus,
    this.chronicIllnesses,
    this.bankName,
    this.bankAccountNumber,
    this.bankBranch,
    this.bankBookUrl,
    this.expectedSalary,
    this.preferredDistricts = const [],
    this.preferredServiceTypes = const [],
    this.serviceAddress,
    this.billingName,
    this.billingAddress,
    this.autoPaymentConsent = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? map['mobile'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String?,
      role: _parseRole(map['role'] as String?),
      kycStatus: _parseKycStatus(map['kycStatus'] as String?),
      isVerified: map['isVerified'] as bool? ?? false,
      isBusy: map['isBusy'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      fcmToken: map['fcmToken'] as String?,
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble(),
      favoriteCaregivers: List<String>.from(map['favoriteCaregivers'] as List? ?? []),
      onLeaveDates: List<String>.from(map['onLeaveDates'] as List? ?? []),
      kycMeetingDateMs: (map['kycMeetingDateMs'] as num?)?.toInt(),
      kycMeetingUrl: map['kycMeetingUrl'] as String?,
      kycMeetingStatus: map['kycMeetingStatus'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      locationLat: (map['locationLat'] as num?)?.toDouble(),
      locationLng: (map['locationLng'] as num?)?.toDouble(),
      nicNumber: map['nicNumber'] as String?,
      dob: map['dob'] as String?,
      gender: map['gender'] as String?,
      address: map['address'] as String?,
      nicFrontUrl: map['nicFrontUrl'] as String?,
      nicBackUrl: map['nicBackUrl'] as String?,
      selfieUrl: map['selfieUrl'] as String?,
      digitalSignatureUrl: map['digitalSignatureUrl'] as String?,
      policeClearanceUrl: map['policeClearanceUrl'] as String?,
      medicalFitnessUrl: map['medicalFitnessUrl'] as String?,
      certificatesUrls: List<String>.from(map['certificatesUrls'] as List? ?? []),
      certificateUrl: map['certificateUrl'] as String?,
      experienceYears: map['experienceYears'] as String?,
      specialSkills: map['specialSkills'] as String?,
      qualifications: map['qualifications'] as String?,
      references: map['references'] as String?,
      categories: List<String>.from(map['categories'] as List? ?? []),
      vaccinationStatus: map['vaccinationStatus'] as String?,
      chronicIllnesses: map['chronicIllnesses'] as String?,
      bankName: map['bankName'] as String?,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      bankBranch: map['bankBranch'] as String?,
      bankBookUrl: map['bankBookUrl'] as String?,
      expectedSalary: (map['expectedSalary'] as num?)?.toDouble(),
      preferredDistricts: List<String>.from(map['preferredDistricts'] as List? ?? []),
      preferredServiceTypes: List<String>.from(map['preferredServiceTypes'] as List? ?? []),
      serviceAddress: map['serviceAddress'] as String?,
      billingName: map['billingName'] as String?,
      billingAddress: map['billingAddress'] as String?,
      autoPaymentConsent: map['autoPaymentConsent'] as bool? ?? false,
    );
  }

  // Writes uppercase values to match care2 exactly
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'profileImageUrl': profileImageUrl,
        'role': role.name.toUpperCase(),
        'kycStatus': _kycStatusToString(kycStatus),
        'isVerified': isVerified,
        'isBusy': isBusy,
        'rating': rating,
        'reviewCount': reviewCount,
        'fcmToken': fcmToken,
        'walletBalance': walletBalance,
        'hourlyRate': hourlyRate,
        'favoriteCaregivers': favoriteCaregivers,
        'onLeaveDates': onLeaveDates,
        'kycMeetingDateMs': kycMeetingDateMs,
        'kycMeetingUrl': kycMeetingUrl,
        'kycMeetingStatus': kycMeetingStatus,
        'rejectionReason': rejectionReason,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'nicNumber': nicNumber,
        'dob': dob,
        'gender': gender,
        'address': address,
        'nicFrontUrl': nicFrontUrl,
        'nicBackUrl': nicBackUrl,
        'selfieUrl': selfieUrl,
        'digitalSignatureUrl': digitalSignatureUrl,
        'policeClearanceUrl': policeClearanceUrl,
        'medicalFitnessUrl': medicalFitnessUrl,
        'certificatesUrls': certificatesUrls,
        'certificateUrl': certificateUrl,
        'experienceYears': experienceYears,
        'specialSkills': specialSkills,
        'qualifications': qualifications,
        'references': references,
        'categories': categories,
        'vaccinationStatus': vaccinationStatus,
        'chronicIllnesses': chronicIllnesses,
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
        'bankBranch': bankBranch,
        'bankBookUrl': bankBookUrl,
        'expectedSalary': expectedSalary,
        'preferredDistricts': preferredDistricts,
        'preferredServiceTypes': preferredServiceTypes,
        'serviceAddress': serviceAddress,
        'billingName': billingName,
        'billingAddress': billingAddress,
        'autoPaymentConsent': autoPaymentConsent,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
    UserRole? role,
    KycStatus? kycStatus,
    bool? isVerified,
    bool? isBusy,
    double? rating,
    int? reviewCount,
    String? fcmToken,
    double? walletBalance,
    double? hourlyRate,
    List<String>? favoriteCaregivers,
    List<String>? onLeaveDates,
    int? kycMeetingDateMs,
    String? kycMeetingUrl,
    String? kycMeetingStatus,
    String? rejectionReason,
    double? locationLat,
    double? locationLng,
    String? nicNumber,
    String? dob,
    String? gender,
    String? address,
    String? nicFrontUrl,
    String? nicBackUrl,
    String? selfieUrl,
    String? digitalSignatureUrl,
    String? policeClearanceUrl,
    String? medicalFitnessUrl,
    List<String>? certificatesUrls,
    String? certificateUrl,
    String? experienceYears,
    String? specialSkills,
    String? qualifications,
    String? references,
    List<String>? categories,
    String? vaccinationStatus,
    String? chronicIllnesses,
    String? bankName,
    String? bankAccountNumber,
    String? bankBranch,
    String? bankBookUrl,
    double? expectedSalary,
    List<String>? preferredDistricts,
    List<String>? preferredServiceTypes,
    String? serviceAddress,
    String? billingName,
    String? billingAddress,
    bool? autoPaymentConsent,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        role: role ?? this.role,
        kycStatus: kycStatus ?? this.kycStatus,
        isVerified: isVerified ?? this.isVerified,
        isBusy: isBusy ?? this.isBusy,
        rating: rating ?? this.rating,
        reviewCount: reviewCount ?? this.reviewCount,
        fcmToken: fcmToken ?? this.fcmToken,
        walletBalance: walletBalance ?? this.walletBalance,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        favoriteCaregivers: favoriteCaregivers ?? this.favoriteCaregivers,
        onLeaveDates: onLeaveDates ?? this.onLeaveDates,
        kycMeetingDateMs: kycMeetingDateMs ?? this.kycMeetingDateMs,
        kycMeetingUrl: kycMeetingUrl ?? this.kycMeetingUrl,
        kycMeetingStatus: kycMeetingStatus ?? this.kycMeetingStatus,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        locationLat: locationLat ?? this.locationLat,
        locationLng: locationLng ?? this.locationLng,
        nicNumber: nicNumber ?? this.nicNumber,
        dob: dob ?? this.dob,
        gender: gender ?? this.gender,
        address: address ?? this.address,
        nicFrontUrl: nicFrontUrl ?? this.nicFrontUrl,
        nicBackUrl: nicBackUrl ?? this.nicBackUrl,
        selfieUrl: selfieUrl ?? this.selfieUrl,
        digitalSignatureUrl: digitalSignatureUrl ?? this.digitalSignatureUrl,
        policeClearanceUrl: policeClearanceUrl ?? this.policeClearanceUrl,
        medicalFitnessUrl: medicalFitnessUrl ?? this.medicalFitnessUrl,
        certificatesUrls: certificatesUrls ?? this.certificatesUrls,
        certificateUrl: certificateUrl ?? this.certificateUrl,
        experienceYears: experienceYears ?? this.experienceYears,
        specialSkills: specialSkills ?? this.specialSkills,
        qualifications: qualifications ?? this.qualifications,
        references: references ?? this.references,
        categories: categories ?? this.categories,
        vaccinationStatus: vaccinationStatus ?? this.vaccinationStatus,
        chronicIllnesses: chronicIllnesses ?? this.chronicIllnesses,
        bankName: bankName ?? this.bankName,
        bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
        bankBranch: bankBranch ?? this.bankBranch,
        bankBookUrl: bankBookUrl ?? this.bankBookUrl,
        expectedSalary: expectedSalary ?? this.expectedSalary,
        preferredDistricts: preferredDistricts ?? this.preferredDistricts,
        preferredServiceTypes: preferredServiceTypes ?? this.preferredServiceTypes,
        serviceAddress: serviceAddress ?? this.serviceAddress,
        billingName: billingName ?? this.billingName,
        billingAddress: billingAddress ?? this.billingAddress,
        autoPaymentConsent: autoPaymentConsent ?? this.autoPaymentConsent,
      );

  bool get isCaregiverOrNurse =>
      role == UserRole.caregiver || role == UserRole.nurse;

  String get roleLabel => switch (role) {
        UserRole.nurse => 'Nurse',
        UserRole.caregiver => 'Caregiver',
        UserRole.client => 'Client',
      };

  bool get isSuperCaregiver =>
      isCaregiverOrNurse && rating >= 4.8 && reviewCount >= 5;

  bool get isKycApproved => kycStatus == KycStatus.approved || isVerified;

  // Read from Firestore, handles care2 uppercase values
  static UserRole _parseRole(String? raw) {
    if (raw == null) return UserRole.client;
    switch (raw.toUpperCase()) {
      case 'CAREGIVER':
        return UserRole.caregiver;
      case 'NURSE':
        return UserRole.nurse;
      default:
        return UserRole.client;
    }
  }

  static KycStatus _parseKycStatus(String? raw) {
    if (raw == null) return KycStatus.pending;
    switch (raw.toUpperCase()) {
      case 'APPROVED':
      case 'VERIFIED':
        return KycStatus.approved;
      case 'REJECTED':
        return KycStatus.rejected;
      default:
        return KycStatus.pending;
    }
  }

  // Write uppercase to match care2
  static String _kycStatusToString(KycStatus status) {
    switch (status) {
      case KycStatus.approved:
        return 'APPROVED';
      case KycStatus.rejected:
        return 'REJECTED';
      case KycStatus.pending:
        return 'PENDING';
    }
  }

  @override
  List<Object?> get props => [
        uid, name, email, phone, profileImageUrl, role, kycStatus,
        isVerified, isBusy, rating, reviewCount, fcmToken, walletBalance,
        hourlyRate, favoriteCaregivers, onLeaveDates, nicNumber, gender,
      ];
}
