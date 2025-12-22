import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scheduled_game.dart';
import 'service_providers.dart';

// Scheduled Games Provider
final scheduledGamesProvider = StateNotifierProvider<ScheduledGamesNotifier, AsyncValue<List<ScheduledGame>>>((ref) {
  return ScheduledGamesNotifier(ref);
});

class ScheduledGamesNotifier extends StateNotifier<AsyncValue<List<ScheduledGame>>> {
  final Ref ref;

  ScheduledGamesNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadScheduledGames();
  }

  Future<void> loadScheduledGames() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final scheduledGames = await db.getAllFutureScheduledGames();
      state = AsyncValue.data(scheduledGames);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<List<ScheduledGame>> getScheduledGamesForGame(int gameId) async {
    final db = ref.read(databaseServiceProvider);
    return await db.getScheduledGamesForGame(gameId);
  }

  Future<ScheduledGame> scheduleGame({
    required int gameId,
    required DateTime scheduledDateTime,
    String? location,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final scheduledGame = ScheduledGame(
      gameId: gameId,
      scheduledDateTime: scheduledDateTime,
      location: location,
    );
    final saved = await db.insertScheduledGame(scheduledGame);
    await loadScheduledGames();
    return saved;
  }

  Future<void> deleteScheduledGame(int scheduledGameId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteScheduledGame(scheduledGameId);
    await loadScheduledGames();
  }

  Future<void> updateScheduledGame(ScheduledGame scheduledGame) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateScheduledGame(scheduledGame);
    await loadScheduledGames();
  }
}
