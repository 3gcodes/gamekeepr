import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collectible.dart';
import 'service_providers.dart';

// Collectibles List Provider
final collectiblesProvider = StateNotifierProvider<CollectiblesNotifier, AsyncValue<List<Collectible>>>((ref) {
  return CollectiblesNotifier(ref);
});

class CollectiblesNotifier extends StateNotifier<AsyncValue<List<Collectible>>> {
  final Ref ref;

  CollectiblesNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadCollectibles();
  }

  Future<void> loadCollectibles() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final collectibles = await db.getAllCollectibles();
      state = AsyncValue.data(collectibles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Collectible> addCollectible(Collectible collectible) async {
    try {
      final db = ref.read(databaseServiceProvider);
      final newCollectible = await db.insertCollectible(collectible);
      await loadCollectibles();
      return newCollectible;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateCollectible(Collectible collectible) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateCollectible(collectible);
      await loadCollectibles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateCollectibleLocation(int collectibleId, String location) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateCollectibleLocation(collectibleId, location);
      await loadCollectibles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateCollectiblePainted(int collectibleId, bool painted) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateCollectiblePainted(collectibleId, painted);
      await loadCollectibles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateCollectibleHasNfcTag(int collectibleId, bool hasNfcTag) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateCollectibleHasNfcTag(collectibleId, hasNfcTag);
      await loadCollectibles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteCollectible(int id) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteCollectible(id);
      await loadCollectibles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Collectible?> getCollectibleById(int id) async {
    final db = ref.read(databaseServiceProvider);
    return await db.getCollectibleById(id);
  }
}

// Collectibles filtered by type
final collectiblesByTypeProvider = Provider.family<AsyncValue<List<Collectible>>, CollectibleType>((ref, type) {
  final collectiblesAsync = ref.watch(collectiblesProvider);
  return collectiblesAsync.whenData((collectibles) {
    return collectibles.where((c) => c.type == type).toList();
  });
});

// Collectibles for a specific game
final collectiblesForGameProvider = Provider.family<AsyncValue<List<Collectible>>, int>((ref, gameId) {
  final collectiblesAsync = ref.watch(collectiblesProvider);
  return collectiblesAsync.whenData((collectibles) {
    return collectibles.where((c) => c.gameId == gameId).toList();
  });
});

// Collectibles search provider
final collectiblesSearchProvider = StateProvider<String>((ref) => '');

final filteredCollectiblesProvider = Provider<AsyncValue<List<Collectible>>>((ref) {
  final collectiblesAsync = ref.watch(collectiblesProvider);
  final searchQuery = ref.watch(collectiblesSearchProvider);

  return collectiblesAsync.whenData((collectibles) {
    if (searchQuery.isEmpty) {
      return collectibles;
    }

    return collectibles.where((collectible) {
      final nameLower = collectible.name.toLowerCase();
      final manufacturerLower = collectible.manufacturer?.toLowerCase() ?? '';
      final queryLower = searchQuery.toLowerCase();

      return nameLower.contains(queryLower) || manufacturerLower.contains(queryLower);
    }).toList();
  });
});

// Selected collectible type filter
final selectedCollectibleTypeProvider = StateProvider<CollectibleType?>((ref) => null);

final filteredCollectiblesByTypeProvider = Provider<AsyncValue<List<Collectible>>>((ref) {
  final filteredAsync = ref.watch(filteredCollectiblesProvider);
  final selectedType = ref.watch(selectedCollectibleTypeProvider);

  return filteredAsync.whenData((collectibles) {
    if (selectedType == null) {
      return collectibles;
    }
    return collectibles.where((c) => c.type == selectedType).toList();
  });
});
