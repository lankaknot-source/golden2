import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn? _gsInstance;
  GoogleSignIn get _googleSignIn => _gsInstance ??= GoogleSignIn(
        clientId: '283184840115-dh6l2j6f0u3ov03nih26slfi4i832ev6.apps.googleusercontent.com',
      );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _fetchUserModel(credential.user!.uid);
  }

  Future<UserModel> signInWithGoogle() async {
    final UserCredential userCredential;
    if (kIsWeb) {
      // Web: Firebase handles the OAuth flow directly via a popup.
      final provider = GoogleAuthProvider()..addScope('email');
      userCredential = await _auth.signInWithPopup(provider);
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _auth.signInWithCredential(credential);
    }
    final fbUser = userCredential.user!;
    final uid = fbUser.uid;

    final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) {
      // New Google user — needs role selection
      final newUser = UserModel(
        uid: uid,
        name: fbUser.displayName ?? '',
        email: fbUser.email ?? '',
        phone: '',
        profileImageUrl: fbUser.photoURL,
        role: UserRole.client,
      );
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(newUser.toMap());
      return newUser;
    }
    return UserModel.fromMap(doc.data()!, uid);
  }

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final user = UserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      role: role,
    );
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(user.toMap());
    return user;
  }

  Future<void> saveGoogleUserRole(String uid, UserRole role) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
      'role': role.name.toUpperCase(),
    });
  }

  Future<void> signOut() async {
    if (kIsWeb) {
      await _auth.signOut();
      return;
    }
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<UserModel> fetchCurrentUser(String uid) => _fetchUserModel(uid);

  /// Saves the device FCM token so the backend can push to this user
  /// (mirrors care2 MyFirebaseMessagingService.onNewToken).
  Future<void> updateFcmToken(String uid, String token) =>
      _firestore.collection(AppConstants.usersCollection).doc(uid).update({
        'fcmToken': token,
      });

  Future<UserModel> _fetchUserModel(String uid) async {
    final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) throw Exception('User profile not found');
    return UserModel.fromMap(doc.data()!, uid);
  }
}
