import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/game_with_play_info.dart';
import '../services/database_service.dart';
import '../services/bgg_service.dart';
import '../services/nfc_service.dart';

// Service Providers
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final bggServiceProvider = Provider<BggService>((ref) {
  final service = BggService();
  // Load API token from shared preferences
  final prefs = ref.watch(sharedPreferencesProvider);
  prefs.whenData((p) {
    final token = p.getString('bgg_api_token') ?? '';
    if (token.isNotEmpty) {
      service.setBearerToken(token);
    }
  });
  return service;
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

// BGG API Token Provider
final bggApiTokenProvider = FutureProvider<String>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getString('bgg_api_token') ?? '';
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

  Future<void> syncFromBgg(String username, String apiToken) async {
    if (username.isEmpty) {
      throw Exception('Username is required');
    }

    if (apiToken.isEmpty) {
      throw Exception('API token is required. Please set it in settings.');
    }

    try {
      final bggService = ref.read(bggServiceProvider);
      final db = ref.read(databaseServiceProvider);

      // Set the API token
      bggService.setBearerToken(apiToken);
      print('🔑 Using API token for BGG authentication');

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

// Expansion Filter Options
enum ExpansionFilter {
  baseGames,      // Default - show only base games and standalone games (no expansions)
  onlyExpansions, // Show only expansions
  all,            // Show everything
}

// Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Expansion Filter Provider
final expansionFilterProvider = StateProvider<ExpansionFilter>((ref) => ExpansionFilter.baseGames);

// Filtered Games Provider
final filteredGamesProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final games = ref.watch(gamesProvider);
  final query = ref.watch(searchQueryProvider);
  final expansionFilter = ref.watch(expansionFilterProvider);

  return games.when(
    data: (gamesList) {
      // Apply expansion filter
      var filtered = gamesList;

      switch (expansionFilter) {
        case ExpansionFilter.baseGames:
          // Show only games that are NOT expansions (baseGame is null)
          filtered = filtered.where((game) => game.baseGame == null).toList();
          break;
        case ExpansionFilter.onlyExpansions:
          // Show only expansions (games with a baseGame)
          filtered = filtered.where((game) => game.baseGame != null).toList();
          break;
        case ExpansionFilter.all:
          // No filtering
          break;
      }

      // Apply search filter
      if (query.isNotEmpty) {
        filtered = filtered
            .where((game) => game.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Recently Played Games Provider
final recentlyPlayedGamesProvider = StateNotifierProvider<RecentlyPlayedGamesNotifier, AsyncValue<List<GameWithPlayInfo>>>((ref) {
  return RecentlyPlayedGamesNotifier(ref);
});

class RecentlyPlayedGamesNotifier extends StateNotifier<AsyncValue<List<GameWithPlayInfo>>> {
  final Ref ref;

  RecentlyPlayedGamesNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadRecentlyPlayedGames();
  }

  Future<void> loadRecentlyPlayedGames() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final gamesData = await db.getGamesWithRecentPlays();
      final gamesWithPlayInfo = gamesData.map((data) => GameWithPlayInfo.fromMap(data)).toList();
      state = AsyncValue.data(gamesWithPlayInfo);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Filtered Recently Played Games Provider
final filteredRecentlyPlayedGamesProvider = Provider<AsyncValue<List<GameWithPlayInfo>>>((ref) {
  final games = ref.watch(recentlyPlayedGamesProvider);
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty) {
    return games;
  }

  return games.when(
    data: (gamesList) {
      final filtered = gamesList
          .where((gameWithInfo) => gameWithInfo.game.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

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
