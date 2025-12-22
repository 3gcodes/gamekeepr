import 'package:flutter_riverpod/flutter_riverpod.dart';

// Main Bottom Navigation Index (0 = Games, 1 = Collectibles, 2 = More)
final mainBottomNavIndexProvider = StateProvider<int>((ref) => 0);

// Games Sub-Tab Index (0 = Collection, 1 = Wishlist, 2 = Save for Later)
final gamesSubTabIndexProvider = StateProvider<int>((ref) => 0);

// Sync Status Provider
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}
