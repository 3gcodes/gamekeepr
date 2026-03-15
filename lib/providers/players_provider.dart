import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import 'service_providers.dart';

// Players Provider
final playersProvider = StateNotifierProvider<PlayersNotifier, AsyncValue<List<Player>>>((ref) {
  return PlayersNotifier(ref);
});

class PlayersNotifier extends StateNotifier<AsyncValue<List<Player>>> {
  final Ref ref;

  PlayersNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadPlayers();
  }

  Future<void> loadPlayers() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final players = await db.getAllPlayers();
      state = AsyncValue.data(players);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Player> addPlayer({
    required String name,
    String? bggUsername,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final player = Player(
      name: name,
      bggUsername: bggUsername,
    );
    final saved = await db.insertPlayer(player);
    await loadPlayers();
    return saved;
  }

  Future<void> deletePlayer(int playerId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deletePlayer(playerId);
    await loadPlayers();
  }
}

// Play Locations Provider (for autocomplete)
final playLocationsProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllPlayLocations();
});
