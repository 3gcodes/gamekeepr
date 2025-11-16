import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
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

// BGG Password Provider
final bggPasswordProvider = FutureProvider<String>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getString('bgg_password') ?? '';
});

// Games List Provider
final gamesProvider = StateNotifierProvider<GamesNotifier, AsyncValue<List<Game>>>((ref) {
  return GamesNotifier(ref);
});

class GamesNotifier extends StateNotifier<AsyncValue<List<Game>>> {
  final Ref ref;

  GamesNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadGames();
  }

  Future<void> loadGames() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final games = await db.getAllGames();
      state = AsyncValue.data(games);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> syncFromBgg(String username, String password) async {
    if (username.isEmpty) {
      throw Exception('Username is required');
    }

    if (password.isEmpty) {
      throw Exception('Password is required for BGG authentication');
    }

    try {
      final bggService = ref.read(bggServiceProvider);
      final db = ref.read(databaseServiceProvider);

      // Login to BGG first
      print('🔐 Logging in to BGG...');
      final loginSuccess = await bggService.login(username, password);

      if (!loginSuccess) {
        throw Exception('Failed to login to BGG. Please check your username and password.');
      }

      print('✅ Successfully logged in to BGG');

      // Fetch games from BGG
      final bggGames = await bggService.fetchCollection(username);

      // Update or insert games in database
      for (final game in bggGames) {
        // Check if game already exists
        final existingGame = await db.getGameByBggId(game.bggId);

        if (existingGame != null) {
          // Update existing game, preserve location
          final updatedGame = game.copyWith(
            id: existingGame.id,
            location: existingGame.location,
          );
          await db.updateGame(updatedGame);
        } else {
          // Insert new game
          await db.insertGame(game);
        }
      }

      // Reload games
      await loadGames();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateGameLocation(int gameId, String location) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateGameLocation(gameId, location);
      await loadGames();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Game?> getGameByBggId(int bggId) async {
    final db = ref.read(databaseServiceProvider);
    return await db.getGameByBggId(bggId);
  }
}

// Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered Games Provider
final filteredGamesProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final games = ref.watch(gamesProvider);
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty) {
    return games;
  }

  return games.when(
    data: (gamesList) {
      final filtered = gamesList
          .where((game) => game.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Sync Status Provider
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}
