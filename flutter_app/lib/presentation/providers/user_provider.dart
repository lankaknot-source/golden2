import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/user_repository.dart';
import '../../domain/models/user_model.dart';

final userRepositoryProvider = Provider<UserRepository>((_) => UserRepository());

final userStreamProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).streamUser(uid);
});

final caregiversProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).searchCaregivers();
});
