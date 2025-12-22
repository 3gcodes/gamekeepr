import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/bgg_service.dart';
import '../services/nfc_service.dart';

// Service Providers
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final bggServiceProvider = Provider<BggService>((ref) {
  return BggService();
});

final nfcServiceProvider = Provider<NfcService>((ref) {
  return NfcService();
});
