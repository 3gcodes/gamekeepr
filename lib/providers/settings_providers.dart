import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Shared Preferences Provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// BGG Username Provider
final bggUsernameProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.when(
    data: (prefs) => prefs.getString('bgg_username') ?? '',
    loading: () => '',
    error: (_, __) => '',
  );
});

// BGG API Token Provider
final bggApiTokenProvider = FutureProvider<String>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getString('bgg_api_token') ?? '';
});
