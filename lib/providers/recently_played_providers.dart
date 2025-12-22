import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_with_play_info.dart';
import 'service_providers.dart';
import 'search_providers.dart';

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
          .where((gameWithInfo) => gameMatchesSearch(
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
