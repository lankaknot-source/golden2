import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.usersCollection);

  Future<UserModel?> getUser(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  Stream<UserModel?> streamUser(String uid) {
    return _col.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, uid);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _col.doc(uid).update(data);

  Future<void> updateFcmToken(String uid, String token) =>
      _col.doc(uid).update({'fcmToken': token});

  // Writes uppercase to match care2
  Future<void> updateKycStatus(String uid, KycStatus status) {
    String value;
    switch (status) {
      case KycStatus.approved:
        value = 'APPROVED';
        break;
      case KycStatus.rejected:
        value = 'REJECTED';
        break;
      case KycStatus.pending:
        value = 'PENDING';
        break;
    }
    return _col.doc(uid).update({'kycStatus': value});
  }

  Future<void> setVerified(String uid) =>
      _col.doc(uid).update({'isVerified': true, 'kycStatus': 'APPROVED'});

  // Matches care2: role IN [CAREGIVER, NURSE], verified/approved, not busy, not on leave today
  Future<List<UserModel>> searchCaregivers({String? query}) async {
    final snap = await _col
        .where('role', whereIn: ['CAREGIVER', 'NURSE'])
        .get();
    final today = _todayStr();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .where((u) {
          final verified = u.isVerified || u.kycStatus == KycStatus.approved;
          final available = !u.isBusy && !u.onLeaveDates.contains(today);
          if (!verified || !available) return false;
          if (query != null && query.isNotEmpty) {
            return u.name.toLowerCase().contains(query.toLowerCase()) ||
                (u.address?.toLowerCase().contains(query.toLowerCase()) ?? false);
          }
          return true;
        })
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
  }

  Future<List<UserModel>> getTopCaregivers({int limit = 5}) async {
    final all = await searchCaregivers();
    return all.take(limit).toList();
  }

  Future<void> toggleFavorite(String uid, String caregiverId, {required bool add}) =>
      _col.doc(uid).update({
        'favoriteCaregivers': add
            ? FieldValue.arrayUnion([caregiverId])
            : FieldValue.arrayRemove([caregiverId]),
      });

  Future<void> updateLocation(String uid, double lat, double lng) =>
      _col.doc(uid).update({'locationLat': lat, 'locationLng': lng});

  Future<void> updateHourlyRate(String uid, double rate) =>
      _col.doc(uid).update({'hourlyRate': rate});

  Future<void> setUserBusy(String uid, bool isBusy) =>
      _col.doc(uid).update({'isBusy': isBusy});

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
