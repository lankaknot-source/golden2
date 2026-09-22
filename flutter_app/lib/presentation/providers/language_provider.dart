import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final isSinhalaProvider = StateNotifierProvider<_LangNotifier, bool>((ref) {
  return _LangNotifier();
});

class _LangNotifier extends StateNotifier<bool> {
  _LangNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('is_sinhala') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sinhala', state);
  }
}
