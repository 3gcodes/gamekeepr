import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import 'games_provider.dart';
import 'search_providers.dart';

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
            .where((game) => gameMatchesSearch(
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
            .where((game) => gameMatchesSearch(
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
            .where((game) => gameMatchesSearch(
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

// Saved for Later Provider (games saved for later)
final savedForLaterProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final games = ref.watch(gamesProvider);
  final query = ref.watch(searchQueryProvider);
  final searchCategories = ref.watch(searchCategoriesProvider);
  final searchMechanics = ref.watch(searchMechanicsProvider);
  final searchTags = ref.watch(searchTagsProvider);
  final tagsMapAsync = ref.watch(gameTagsMapProvider);

  return games.when(
    data: (gamesList) {
      // Filter to only show saved for later games
      var filtered = gamesList.where((game) => game.savedForLater).toList();

      // Apply search filter
      if (query.isNotEmpty) {
        final tagsMap = tagsMapAsync.whenOrNull(data: (map) => map) ?? {};
        filtered = filtered
            .where((game) => gameMatchesSearch(
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
