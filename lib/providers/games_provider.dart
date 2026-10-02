import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/game.dart';
import 'service_providers.dart';

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

    final bggService = ref.read(bggServiceProvider);
    final db = ref.read(databaseServiceProvider);

    // BGG IDs of games we still need details for
    final needDetails = <int>[];

    try {
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
          // Update what the collection knows about, preserve everything else
          // (location, owned status, details, market value, ...)
          final updatedGame = existingGame.copyWith(
            name: game.name,
            imageUrl: game.imageUrl,
            thumbnailUrl: game.thumbnailUrl,
            yearPublished: game.yearPublished,
          );
          await db.updateGame(updatedGame);
          if (!_hasDetails(existingGame)) {
            needDetails.add(game.bggId);
          }
        } else {
          // Insert new game (from collection sync, so mark as owned)
          await db.insertGame(game.copyWith(owned: true));
          needDetails.add(game.bggId);
        }
      }

      // Reload games
      await loadGames();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }

    if (needDetails.isEmpty) return;

    // The collection response has no player counts, categories or mechanics,
    // so fetch the details for games that don't have them yet
    try {
      print('🔍 Fetching details for ${needDetails.length} games');
      await for (final detailedGames in bggService.fetchGamesDetails(needDetails)) {
        for (final details in detailedGames) {
          final game = await db.getGameByBggId(details.bggId);
          if (game == null) continue;

          await db.updateGame(game.withDetails(details));
        }
      }
    } finally {
      // Reload games, keeping whatever details were saved before a failure
      await loadGames();
    }
  }

  // Whether a game's details (players, categories, mechanics, ...) have been fetched
  bool _hasDetails(Game game) {
    return game.description != null && game.maxPlayers != null;
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

  /// Toggle the saved for later status of a game
  Future<Game?> toggleSavedForLater(int gameId, bool savedForLater) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateGameSavedForLater(gameId, savedForLater);
    await loadGames();
    return await db.getGameById(gameId);
  }

  /// Toggle the owned status of a game
  Future<Game?> toggleOwned(int gameId, bool owned) async {
    final db = ref.read(databaseServiceProvider);

    // Update local database first
    await db.updateGameOwned(gameId, owned);

    // Try to sync with BGG if credentials are available
    try {
      final game = await db.getGameById(gameId);
      if (game == null) {
        print('⚠️ Cannot sync with BGG: game not found');
        await loadGames();
        return game;
      }

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('bgg_username') ?? '';
      const secureStorage = FlutterSecureStorage();
      final password = await secureStorage.read(key: 'bgg_password') ?? '';

      if (username.isEmpty || password.isEmpty) {
        print('⚠️ BGG credentials not set, skipping BGG sync');
        await loadGames();
        return game;
      }

      final bggService = ref.read(bggServiceProvider);

      // Login to BGG if not already logged in
      if (!bggService.isLoggedIn) {
        print('🔐 Logging in to BGG...');
        await bggService.login(username, password);
      }

      // Update BGG collection
      print('🔄 Syncing ownership status with BGG...');
      await bggService.updateGameOwnership(
        game.bggId,
        owned,
        gameName: game.name,
        imageUrl: game.imageUrl,
        thumbnailUrl: game.thumbnailUrl,
      );
      print('✅ Successfully synced with BGG');
    } catch (e) {
      // Don't fail the local update if BGG sync fails
      print('⚠️ Failed to sync with BGG: $e');
      // User will still see the local update
    }

    await loadGames();
    return await db.getGameById(gameId);
  }
}
