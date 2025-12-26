import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/s3_service.dart';

// Shared Preferences Provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// Secure Storage Provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
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

// S3 Enabled Provider
final s3EnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('s3_enabled') ?? false;
});

// S3 Configuration Provider
final s3ConfigProvider = FutureProvider<Map<String, String>>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final storage = ref.watch(secureStorageProvider);

  final bucket = prefs.getString('s3_bucket') ?? '';
  final region = prefs.getString('s3_region') ?? 'us-east-1';
  final accessKey = await storage.read(key: 's3_access_key') ?? '';
  final secretKey = await storage.read(key: 's3_secret_key') ?? '';

  return {
    'bucket': bucket,
    'region': region,
    'accessKey': accessKey,
    'secretKey': secretKey,
  };
});

// S3 Service Provider
final s3ServiceProvider = FutureProvider<S3Service?>((ref) async {
  final enabled = await ref.watch(s3EnabledProvider.future);
  if (!enabled) return null;

  final config = await ref.watch(s3ConfigProvider.future);
  final bucket = config['bucket'] ?? '';
  final region = config['region'] ?? 'us-east-1';
  final accessKey = config['accessKey'] ?? '';
  final secretKey = config['secretKey'] ?? '';

  // Only create service if all required fields are present
  if (bucket.isEmpty || accessKey.isEmpty || secretKey.isEmpty) {
    return null;
  }

  return S3Service(
    bucketName: bucket,
    region: region,
    accessKey: accessKey,
    secretKey: secretKey,
  );
});
