import 'package:flutter_riverpod/flutter_riverpod.dart';

// Current View Tab Provider (0 = Collection, 1 = Recently Played)
final currentViewTabProvider = StateProvider<int>((ref) => 0);

// Sync Status Provider
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}
