// Safely parse a value that may arrive as num or String from Firestore.
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

class User {
  String id;
  String name;
  String email;
  String phone;
  String mobile;
  String role;
  String profileImageUrl;
  String kycStatus;
  bool isVerified;
  String nicNumber;
  double rating;
  int reviewCount;
  String dob;
  bool isBusy;
  List<String> onLeaveDates;
  double hourlyRate;
  int experienceYears;
  List<String> favoriteCaregivers;
  String address;

  User({
    this.id = "",
    this.name = "",
    this.email = "",
    this.phone = "",
    this.mobile = "",
    this.role = "CLIENT",
    this.profileImageUrl = "",
    this.kycStatus = "PENDING",
    this.isVerified = false,
    this.nicNumber = "",
    this.rating = 0.0,
    this.reviewCount = 0,
    this.dob = "",
    this.isBusy = false,
    this.onLeaveDates = const [],
    this.hourlyRate = 0.0,
    this.experienceYears = 0,
    this.favoriteCaregivers = const [],
    this.address = "",
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String? ?? "",
      name: map['name'] as String? ?? "",
      email: map['email'] as String? ?? "",
      phone: map['phone'] as String? ?? "",
      mobile: map['mobile'] as String? ?? "",
      role: map['role'] as String? ?? "CLIENT",
      profileImageUrl: map['profileImageUrl'] as String? ?? "",
      kycStatus: map['kycStatus'] as String? ?? "PENDING",
      isVerified: map['isVerified'] as bool? ?? false,
      nicNumber: map['nicNumber'] as String? ?? "",
      rating: _toDouble(map['rating']) ?? 0.0,
      reviewCount: _toInt(map['reviewCount']) ?? 0,
      dob: map['dob'] as String? ?? "",
      isBusy: map['isBusy'] as bool? ?? false,
      onLeaveDates: (map['onLeaveDates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      hourlyRate: _toDouble(map['hourlyRate']) ?? 0.0,
      experienceYears: _toInt(map['experienceYears']) ?? 0,
      favoriteCaregivers: (map['favoriteCaregivers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      address: map['address'] as String? ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'mobile': mobile,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'kycStatus': kycStatus,
      'isVerified': isVerified,
      'nicNumber': nicNumber,
      'rating': rating,
      'reviewCount': reviewCount,
      'dob': dob,
      'isBusy': isBusy,
      'onLeaveDates': onLeaveDates,
      'hourlyRate': hourlyRate,
      'experienceYears': experienceYears,
      'favoriteCaregivers': favoriteCaregivers,
      'address': address,
    };
  }
}

class MedicineReminder {
  String id;
  String time;
  String name;
  String photoBase64;

  MedicineReminder({
    this.id = "",
    this.time = "",
    this.name = "",
    this.photoBase64 = "",
  });

  factory MedicineReminder.fromMap(Map<String, dynamic> map) {
    return MedicineReminder(
      id: map['id'] as String? ?? "",
      time: map['time'] as String? ?? "",
      name: map['name'] as String? ?? "",
      photoBase64: map['photoBase64'] as String? ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'time': time,
      'name': name,
      'photoBase64': photoBase64,
    };
  }
}

class ElderProfile {
  String id;
  String clientId;
  String name;
  int age;
  String gender;
  List<String> medicalConditions;
  String emergencyContact;
  String requiredLanguage;
  List<MedicineReminder> medicineList;

  ElderProfile({
    this.id = "",
    this.clientId = "",
    this.name = "",
    this.age = 0,
    this.gender = "",
    this.medicalConditions = const [],
    this.emergencyContact = "",
    this.requiredLanguage = "",
    this.medicineList = const [],
  });

  factory ElderProfile.fromMap(Map<String, dynamic> map) {
    return ElderProfile(
      id: map['id'] as String? ?? "",
      clientId: map['clientId'] as String? ?? "",
      name: map['name'] as String? ?? "",
      age: _toInt(map['age']) ?? 0,
      gender: map['gender'] as String? ?? "",
      medicalConditions: (map['medicalConditions'] as List<dynamic>?)?.map((x) => x.toString()).toList() ?? [],
      emergencyContact: map['emergencyContact'] as String? ?? "",
      requiredLanguage: map['requiredLanguage'] as String? ?? "",
      medicineList: (map['medicineList'] as List<dynamic>?)?.map((x) => MedicineReminder.fromMap(x as Map<String, dynamic>)).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'name': name,
      'age': age,
      'gender': gender,
      'medicalConditions': medicalConditions,
      'emergencyContact': emergencyContact,
      'requiredLanguage': requiredLanguage,
      'medicineList': medicineList.map((x) => x.toMap()).toList(),
    };
  }
}

class TaskProof {
  String taskName;
  String photoUrl;
  int timestamp;

  TaskProof({
    this.taskName = "",
    this.photoUrl = "",
    this.timestamp = 0,
  });

  factory TaskProof.fromMap(Map<String, dynamic> map) {
    return TaskProof(
      taskName: map['taskName'] as String? ?? "",
      photoUrl: map['photoUrl'] as String? ?? "",
      timestamp: _toInt(map['timestamp']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskName': taskName,
      'photoUrl': photoUrl,
      'timestamp': timestamp,
    };
  }
}

class SubscriptionPlan {
  String id;
  String title;
  String description;
  double price;
  List<String> assignedCaregivers;

  SubscriptionPlan({
    this.id = "",
    this.title = "",
    this.description = "",
    this.price = 0.0,
    this.assignedCaregivers = const [],
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      id: map['id'] as String? ?? "",
      title: map['title'] as String? ?? "",
      description: map['description'] as String? ?? "",
      price: _toDouble(map['price']) ?? 0.0,
      assignedCaregivers: (map['assignedCaregivers'] as List<dynamic>?)?.map((x) => x.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'assignedCaregivers': assignedCaregivers,
    };
  }
}

class Booking {
  String id;
  String clientId;
  String? caregiverId;
  String elderId;
  List<String> appliedCaregivers;
  String careCategory;
  double locationLat;
  double locationLng;
  String status;
  bool isEmergency;
  int requestedTime;
  String jobDescription;
  bool isSubscriptionBooking;
  String planName;
  List<String> allowedCaregivers;
  double totalAmount;
  bool isPaid;
  int scheduledTime;
  String serviceType;
  String durationType;
  List<String> requestedTasks;
  int estimatedHours;
  double hourlyRate;
  List<TaskProof> taskProofs;
  List<String> completedTasks;
  List<String> rejectedBy;
  bool isRated;
  String startCode;

  Booking({
    this.id = "",
    this.clientId = "",
    this.caregiverId,
    this.elderId = "",
    this.appliedCaregivers = const [],
    this.careCategory = "",
    this.locationLat = 0.0,
    this.locationLng = 0.0,
    this.status = "PENDING",
    this.isEmergency = false,
    this.requestedTime = 0,
    this.jobDescription = "",
    this.isSubscriptionBooking = false,
    this.planName = "",
    this.allowedCaregivers = const [],
    this.totalAmount = 0.0,
    this.isPaid = false,
    this.scheduledTime = 0,
    this.serviceType = "",
    this.durationType = "",
    this.requestedTasks = const [],
    this.estimatedHours = 0,
    this.hourlyRate = 0.0,
    this.taskProofs = const [],
    this.completedTasks = const [],
    this.rejectedBy = const [],
    this.isRated = false,
    this.startCode = "",
  });

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] as String? ?? "",
      clientId: map['clientId'] as String? ?? "",
      caregiverId: map['caregiverId'] as String?,
      elderId: map['elderId'] as String? ?? "",
      appliedCaregivers: (map['appliedCaregivers'] as List<dynamic>?)?.map((x) => x.toString()).toList() ?? [],
      careCategory: map['careCategory'] as String? ?? "",
      locationLat: _toDouble(map['locationLat']) ?? 0.0,
      locationLng: _toDouble(map['locationLng']) ?? 0.0,
      status: map['status'] as String? ?? "PENDING",
      isEmergency: map['isEmergency'] as bool? ?? false,
      requestedTime: _toInt(map['requestedTime']) ?? 0,
      jobDescription: map['jobDescription'] as String? ?? "",
      isSubscriptionBooking: map['isSubscriptionBooking'] as bool? ?? false,
      planName: map['planName'] as String? ?? "",
      allowedCaregivers: (map['allowedCaregivers'] as List<dynamic>?)?.map((x) => x.toString()).toList() ?? [],
      totalAmount: _toDouble(map['totalAmount']) ?? 0.0,
      isPaid: map['isPaid'] as bool? ?? false,
      scheduledTime: _toInt(map['scheduledTime']) ?? 0,
      serviceType: map['serviceType'] as String? ?? "",
      durationType: map['durationType'] as String? ?? "",
      requestedTasks: (map['requestedTasks'] as List<dynamic>?)?.map((x) => x.toString()).toList() ?? [],
      estimatedHours: _toInt(map['estimatedHours']) ?? 0,
      hourlyRate: _toDouble(map['hourlyRate']) ?? 0.0,
      taskProofs: (map['taskProofs'] as List<dynamic>?)?.map((x) => TaskProof.fromMap(x as Map<String, dynamic>)).toList() ?? [],
      completedTasks: (map['completedTasks'] as List<dynamic>?)?.map((x) => x.toString()).toList() ?? [],
      rejectedBy: (map['rejectedBy'] as List<dynamic>?)?.map((x) => x.toString()).toList() ?? [],
      isRated: map['isRated'] as bool? ?? false,
      startCode: map['startCode'] as String? ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'caregiverId': caregiverId,
      'elderId': elderId,
      'appliedCaregivers': appliedCaregivers,
      'careCategory': careCategory,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'status': status,
      'isEmergency': isEmergency,
      'requestedTime': requestedTime,
      'jobDescription': jobDescription,
      'isSubscriptionBooking': isSubscriptionBooking,
      'planName': planName,
      'allowedCaregivers': allowedCaregivers,
      'totalAmount': totalAmount,
      'isPaid': isPaid,
      'scheduledTime': scheduledTime,
      'serviceType': serviceType,
      'durationType': durationType,
      'requestedTasks': requestedTasks,
      'estimatedHours': estimatedHours,
      'hourlyRate': hourlyRate,
      'taskProofs': taskProofs.map((x) => x.toMap()).toList(),
      'completedTasks': completedTasks,
      'rejectedBy': rejectedBy,
      'isRated': isRated,
      'startCode': startCode,
    };
  }
}

class ChatMessage {
  String id;
  String bookingId;
  String senderId;
  String senderName;
  String text;
  String? imageUrl;
  int timestamp;

  ChatMessage({
    this.id = "",
    this.bookingId = "",
    this.senderId = "",
    this.senderName = "",
    this.text = "",
    this.imageUrl,
    this.timestamp = 0,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String? ?? "",
      bookingId: map['bookingId'] as String? ?? "",
      senderId: map['senderId'] as String? ?? "",
      senderName: map['senderName'] as String? ?? "",
      text: map['text'] as String? ?? "",
      imageUrl: map['imageUrl'] as String?,
      timestamp: _toInt(map['timestamp']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
    };
  }
}

class Review {
  String id;
  String bookingId;
  String caregiverId;
  String clientId;
  double rating;
  String comment;
  int timestamp;

  Review({
    this.id = "",
    this.bookingId = "",
    this.caregiverId = "",
    this.clientId = "",
    this.rating = 0.0,
    this.comment = "",
    this.timestamp = 0,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] as String? ?? "",
      bookingId: map['bookingId'] as String? ?? "",
      caregiverId: map['caregiverId'] as String? ?? "",
      clientId: map['clientId'] as String? ?? "",
      rating: _toDouble(map['rating']) ?? 0.0,
      comment: map['comment'] as String? ?? "",
      timestamp: _toInt(map['timestamp']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'caregiverId': caregiverId,
      'clientId': clientId,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
    };
  }
}

class WalletTransaction {
  String id;
  String userId;
  double amount;
  String type;
  String description;
  int timestamp;

  WalletTransaction({
    this.id = "",
    this.userId = "",
    this.amount = 0.0,
    this.type = "CREDIT",
    this.description = "",
    this.timestamp = 0,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] as String? ?? "",
      userId: map['userId'] as String? ?? "",
      amount: _toDouble(map['amount']) ?? 0.0,
      type: map['type'] as String? ?? "CREDIT",
      description: map['description'] as String? ?? "",
      timestamp: _toInt(map['timestamp']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type,
      'description': description,
      'timestamp': timestamp,
    };
  }
}

class LeaveRequest {
  String id;
  String caregiverId;
  String caregiverName;
  int dateMs;
  String dateString;
  String reason;
  String status;
  int requestedAt;

  LeaveRequest({
    this.id = "",
    this.caregiverId = "",
    this.caregiverName = "",
    this.dateMs = 0,
    this.dateString = "",
    this.reason = "",
    this.status = "PENDING",
    this.requestedAt = 0,
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] as String? ?? "",
      caregiverId: map['caregiverId'] as String? ?? "",
      caregiverName: map['caregiverName'] as String? ?? "",
      dateMs: _toInt(map['dateMs']) ?? 0,
      dateString: map['dateString'] as String? ?? "",
      reason: map['reason'] as String? ?? "",
      status: map['status'] as String? ?? "PENDING",
      requestedAt: _toInt(map['requestedAt']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'caregiverId': caregiverId,
      'caregiverName': caregiverName,
      'dateMs': dateMs,
      'dateString': dateString,
      'reason': reason,
      'status': status,
      'requestedAt': requestedAt,
    };
  }
}

class DailyCareLog {
  String id;
  String bookingId;
  String caregiverId;
  String elderId;
  String sugarLevel;
  String bloodPressure;
  String temperature;
  String mealStatus;
  bool medicationGiven;
  String notes;
  int timestamp;

  DailyCareLog({
    this.id = "",
    this.bookingId = "",
    this.caregiverId = "",
    this.elderId = "",
    this.sugarLevel = "",
    this.bloodPressure = "",
    this.temperature = "",
    this.mealStatus = "",
    this.medicationGiven = false,
    this.notes = "",
    this.timestamp = 0,
  });

  factory DailyCareLog.fromMap(Map<String, dynamic> map) {
    return DailyCareLog(
      id: map['id'] as String? ?? "",
      bookingId: map['bookingId'] as String? ?? "",
      caregiverId: map['caregiverId'] as String? ?? "",
      elderId: map['elderId'] as String? ?? "",
      sugarLevel: map['sugarLevel'] as String? ?? "",
      bloodPressure: map['bloodPressure'] as String? ?? "",
      temperature: map['temperature'] as String? ?? "",
      mealStatus: map['mealStatus'] as String? ?? "",
      medicationGiven: map['medicationGiven'] as bool? ?? false,
      notes: map['notes'] as String? ?? "",
      timestamp: _toInt(map['timestamp']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'caregiverId': caregiverId,
      'elderId': elderId,
      'sugarLevel': sugarLevel,
      'bloodPressure': bloodPressure,
      'temperature': temperature,
      'mealStatus': mealStatus,
      'medicationGiven': medicationGiven,
      'notes': notes,
      'timestamp': timestamp,
    };
  }
}
