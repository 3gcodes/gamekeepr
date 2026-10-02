import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_with_play_info.dart';
import 'service_providers.dart';
import 'search_providers.dart';

/// The selectable date windows for the Recently Played view.
enum RecentlyPlayedRange {
  currentWeek('This Week'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  last3Months('Last 3 Months');

  const RecentlyPlayedRange(this.label);

  final String label;

  /// Inclusive [start, end] day bounds for this range relative to [now].
  ({DateTime start, DateTime end}) bounds([DateTime? now]) {
    final today = now ?? DateTime.now();
    switch (this) {
      case RecentlyPlayedRange.currentWeek:
        // Monday of the current week through today.
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (start: start, end: today);
      case RecentlyPlayedRange.thisMonth:
        return (start: DateTime(today.year, today.month, 1), end: today);
      case RecentlyPlayedRange.lastMonth:
        final start = DateTime(today.year, today.month - 1, 1);
        // Last day of the previous month.
        final end = DateTime(today.year, today.month, 1).subtract(const Duration(days: 1));
        return (start: start, end: end);
      case RecentlyPlayedRange.last3Months:
        return (start: DateTime(today.year, today.month - 3, today.day), end: today);
    }
  }
}

// Currently selected date range for the Recently Played view.
final recentlyPlayedRangeProvider = StateProvider<RecentlyPlayedRange>(
  (ref) => RecentlyPlayedRange.currentWeek,
);

// Recently Played Games Provider (bounded to the selected date range)
final recentlyPlayedGamesProvider = StateNotifierProvider<RecentlyPlayedGamesNotifier, AsyncValue<List<GameWithPlayInfo>>>((ref) {
  return RecentlyPlayedGamesNotifier(ref);
});

class RecentlyPlayedGamesNotifier extends StateNotifier<AsyncValue<List<GameWithPlayInfo>>> {
  final Ref ref;

  RecentlyPlayedGamesNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadRecentlyPlayedGames();
    // Reload whenever the selected range changes.
    ref.listen(recentlyPlayedRangeProvider, (_, __) => loadRecentlyPlayedGames());
  }

  Future<void> loadRecentlyPlayedGames() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final bounds = ref.read(recentlyPlayedRangeProvider).bounds();
      final games = await db.getRecentlyPlayedGamesInRange(bounds.start, bounds.end);
      state = AsyncValue.data(games);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// All-time recently played games, loaded lazily and used only for search
// (search spans all of time, ignoring the selected range).
final allTimeRecentlyPlayedGamesProvider = FutureProvider<List<GameWithPlayInfo>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  final gamesData = await db.getGamesWithRecentPlays();
  return gamesData.map((data) => GameWithPlayInfo.fromMap(data)).toList();
});

// Filtered Recently Played Games Provider
final filteredRecentlyPlayedGamesProvider = Provider<AsyncValue<List<GameWithPlayInfo>>>((ref) {
  final query = ref.watch(searchQueryProvider);

  // No search: show only the bounded date-range window.
  if (query.isEmpty) {
    return ref.watch(recentlyPlayedGamesProvider);
  }

  // Searching: match against all plays across all time.
  final games = ref.watch(allTimeRecentlyPlayedGamesProvider);
  final searchCategories = ref.watch(searchCategoriesProvider);
  final searchMechanics = ref.watch(searchMechanicsProvider);
  final searchTags = ref.watch(searchTagsProvider);
  final tagsMapAsync = ref.watch(gameTagsMapProvider);

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
