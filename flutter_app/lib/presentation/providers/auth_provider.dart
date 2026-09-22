import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/notification_service.dart';
import '../../domain/models/user_model.dart';

// ── State ─────────────────────────────────────────────────────────────────────

abstract class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthLoading()) {
    _repo.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        state = const AuthUnauthenticated();
        return;
      }
      try {
        final user = await _repo.fetchCurrentUser(firebaseUser.uid);
        state = AuthAuthenticated(user);
        _registerFcmToken(firebaseUser.uid);
      } catch (_) {
        state = const AuthUnauthenticated();
      }
    });

    // Keep the saved FCM token fresh when Firebase rotates it.
    NotificationService().onTokenRefresh.listen((token) {
      final uid = currentUser?.uid;
      if (uid != null) _repo.updateFcmToken(uid, token);
    });
  }

  /// Fetches the current device FCM token and stores it on the user document
  /// so the backend (Cloud Functions) can push notifications to this device.
  Future<void> _registerFcmToken(String uid) async {
    try {
      final token = await NotificationService().getToken();
      if (token != null) await _repo.updateFcmToken(uid, token);
    } catch (_) {}
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthLoading();
    try {
      final user = await _repo.signInWithEmail(email, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      final user = await _repo.signInWithGoogle();
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _repo.sendPasswordResetEmail(email);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthUnauthenticated();
  }

  UserModel? get currentUser =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).user : null;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);

final currentUserProvider = Provider<UserModel?>((ref) {
  final state = ref.watch(authProvider);
  return state is AuthAuthenticated ? state.user : null;
});
