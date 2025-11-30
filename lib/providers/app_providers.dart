import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/game_with_play_info.dart';
import '../models/scheduled_game.dart';
import '../models/game_loan.dart';
import '../models/game_with_loan_info.dart';
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

  /// Save a game from BGG search to the local database (not owned)
  /// If the game already exists, returns the existing game without modification
  Future<Game> saveGameFromBggSearch(Game game) async {
    final db = ref.read(databaseServiceProvider);

    // Check if game already exists
    final existingGame = await db.getGameByBggId(game.bggId);
    if (existingGame != null) {
      return existingGame;
    }

    // Insert new game with owned = false
    final gameToSave = game.copyWith(owned: false);
    final savedGame = await db.insertGame(gameToSave);

    // Reload games list
    await loadGames();

    return savedGame;
  }

  /// Toggle the wishlist status of a game
  Future<Game?> toggleWishlist(int gameId, bool wishlisted) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateGameWishlisted(gameId, wishlisted);
    await loadGames();
    return await db.getGameById(gameId);
  }

  /// Toggle the owned status of a game
  Future<Game?> toggleOwned(int gameId, bool owned) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateGameOwned(gameId, owned);
    await loadGames();
    return await db.getGameById(gameId);
  }
}

// Expansion Filter Options
enum ExpansionFilter {
  baseGames,      // Default - show only base games and standalone games (no expansions)
  onlyExpansions, // Show only expansions
  all,            // Show everything
}

// Helper function to check if a game matches the search query
bool _gameMatchesSearch(
  Game game,
  String query,
  bool searchCategories,
  bool searchMechanics,
  bool searchTags,
  Map<int, List<String>> tagsMap,
) {
  final lowerQuery = query.toLowerCase();

  // Always search name
  if (game.name.toLowerCase().contains(lowerQuery)) {
    return true;
  }

  // Search categories if enabled
  if (searchCategories && game.categories != null) {
    for (var category in game.categories!) {
      if (category.toLowerCase().contains(lowerQuery)) {
        return true;
      }
    }
  }

  // Search mechanics if enabled
  if (searchMechanics && game.mechanics != null) {
    for (var mechanic in game.mechanics!) {
      if (mechanic.toLowerCase().contains(lowerQuery)) {
        return true;
      }
    }
  }

  // Search tags if enabled
  if (searchTags && game.id != null) {
    final tags = tagsMap[game.id];
    if (tags != null) {
      for (var tag in tags) {
        if (tag.toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
    }
  }

  return false;
}

// Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Search Filter Providers
final searchCategoriesProvider = StateProvider<bool>((ref) => false);
final searchMechanicsProvider = StateProvider<bool>((ref) => false);
final searchTagsProvider = StateProvider<bool>((ref) => false);

// Game Tags Provider - loads all tags grouped by game ID
final gameTagsMapProvider = FutureProvider<Map<int, List<String>>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final games = await db.getAllGames();
  final tagsMap = <int, List<String>>{};

  for (final game in games) {
    if (game.id != null) {
      final tags = await db.getTagsForGame(game.id!);
      if (tags.isNotEmpty) {
        tagsMap[game.id!] = tags;
      }
    }
  }

  return tagsMap;
});

// All Unique Tags Provider (for autocomplete)
final allUniqueTagsProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllUniqueTags();
});

// Expansion Filter Provider
final expansionFilterProvider = StateProvider<ExpansionFilter>((ref) => ExpansionFilter.baseGames);

// Filtered Games Provider (Collection - owned games only)
final filteredGamesProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final games = ref.watch(gamesProvider);
  final query = ref.watch(searchQueryProvider);
  final expansionFilter = ref.watch(expansionFilterProvider);
  final searchCategories = ref.watch(searchCategoriesProvider);
  final searchMechanics = ref.watch(searchMechanicsProvider);
  final searchTags = ref.watch(searchTagsProvider);
  final tagsMapAsync = ref.watch(gameTagsMapProvider);

  return games.when(
    data: (gamesList) {
      // First, filter to only show owned games in collection
      var filtered = gamesList.where((game) => game.owned).toList();

      // Apply expansion filter
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
        final tagsMap = tagsMapAsync.whenOrNull(data: (map) => map) ?? {};
        filtered = filtered
            .where((game) => _gameMatchesSearch(
                  game,
                  query,
                  searchCategories,
                  searchMechanics,
                  searchTags,
                  tagsMap,
                ))
            .toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// All Games Provider (all games - owned and not owned)
final allGamesFilteredProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final games = ref.watch(gamesProvider);
  final query = ref.watch(searchQueryProvider);
  final expansionFilter = ref.watch(expansionFilterProvider);
  final searchCategories = ref.watch(searchCategoriesProvider);
  final searchMechanics = ref.watch(searchMechanicsProvider);
  final searchTags = ref.watch(searchTagsProvider);
  final tagsMapAsync = ref.watch(gameTagsMapProvider);

  return games.when(
    data: (gamesList) {
      // Show all games (owned and not owned)
      var filtered = gamesList;

      // Apply expansion filter
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
        final tagsMap = tagsMapAsync.whenOrNull(data: (map) => map) ?? {};
        filtered = filtered
            .where((game) => _gameMatchesSearch(
                  game,
                  query,
                  searchCategories,
                  searchMechanics,
                  searchTags,
                  tagsMap,
                ))
            .toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Wishlist Provider (games on wishlist)
final wishlistProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final games = ref.watch(gamesProvider);
  final query = ref.watch(searchQueryProvider);
  final searchCategories = ref.watch(searchCategoriesProvider);
  final searchMechanics = ref.watch(searchMechanicsProvider);
  final searchTags = ref.watch(searchTagsProvider);
  final tagsMapAsync = ref.watch(gameTagsMapProvider);

  return games.when(
    data: (gamesList) {
      // Filter to only show wishlisted games
      var filtered = gamesList.where((game) => game.wishlisted).toList();

      // Apply search filter
      if (query.isNotEmpty) {
        final tagsMap = tagsMapAsync.whenOrNull(data: (map) => map) ?? {};
        filtered = filtered
            .where((game) => _gameMatchesSearch(
                  game,
                  query,
                  searchCategories,
                  searchMechanics,
                  searchTags,
                  tagsMap,
                ))
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
  final searchCategories = ref.watch(searchCategoriesProvider);
  final searchMechanics = ref.watch(searchMechanicsProvider);
  final searchTags = ref.watch(searchTagsProvider);
  final tagsMapAsync = ref.watch(gameTagsMapProvider);

  if (query.isEmpty) {
    return games;
  }

  return games.when(
    data: (gamesList) {
      final tagsMap = tagsMapAsync.whenOrNull(data: (map) => map) ?? {};
      final filtered = gamesList
          .where((gameWithInfo) => _gameMatchesSearch(
                gameWithInfo.game,
                query,
                searchCategories,
                searchMechanics,
                searchTags,
                tagsMap,
              ))
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

// Game Loans Provider
final loansProvider = StateNotifierProvider<LoansNotifier, AsyncValue<List<GameWithLoanInfo>>>((ref) {
  return LoansNotifier(ref);
});

class LoansNotifier extends StateNotifier<AsyncValue<List<GameWithLoanInfo>>> {
  final Ref ref;

  LoansNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadActiveLoans();
  }

  Future<void> loadActiveLoans() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final loans = await db.getActiveLoansWithGameInfo();
      state = AsyncValue.data(loans);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<List<GameLoan>> getLoansForGame(int gameId) async {
    final db = ref.read(databaseServiceProvider);
    return await db.getLoansForGame(gameId);
  }

  Future<GameLoan?> getActiveLoanForGame(int gameId) async {
    final db = ref.read(databaseServiceProvider);
    return await db.getActiveLoanForGame(gameId);
  }

  Future<GameLoan> loanGame({
    required int gameId,
    required String borrowerName,
    required DateTime loanDate,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final loan = GameLoan(
      gameId: gameId,
      borrowerName: borrowerName,
      loanDate: loanDate,
    );
    final saved = await db.insertGameLoan(loan);
    await loadActiveLoans();
    return saved;
  }

  Future<void> returnGame(int loanId) async {
    final db = ref.read(databaseServiceProvider);
    await db.returnGame(loanId);
    await loadActiveLoans();
  }

  Future<void> updateLoan(GameLoan loan) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateGameLoan(loan);
    await loadActiveLoans();
  }

  Future<void> deleteLoan(int loanId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteGameLoan(loanId);
    await loadActiveLoans();
  }
}

// Borrower Names Provider (for autocomplete)
final borrowerNamesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllBorrowerNames();
});
