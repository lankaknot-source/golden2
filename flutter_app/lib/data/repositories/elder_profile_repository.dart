import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/elder_profile_model.dart';

class ElderProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.elderProfilesCollection);

  Future<String> addProfile(ElderProfile profile) async {
    final ref = await _col.add(profile.toMap());
    return ref.id;
  }

  Future<ElderProfile?> getProfile(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ElderProfile.fromMap(doc.data()!, doc.id);
  }

  Stream<List<ElderProfile>> streamClientProfiles(String clientId) {
    return _col
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((s) => s.docs.map((d) => ElderProfile.fromMap(d.data(), d.id)).toList());
  }

  Future<List<ElderProfile>> getClientProfiles(String clientId) async {
    final snap = await _col.where('clientId', isEqualTo: clientId).get();
    return snap.docs.map((d) => ElderProfile.fromMap(d.data(), d.id)).toList();
  }

  Future<void> updateProfile(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> updateMedicineList(String id, List<MedicineReminder> list) =>
      _col.doc(id).update({'medicineList': list.map((r) => r.toMap()).toList()});

  Future<void> deleteProfile(String id) => _col.doc(id).delete();
}
