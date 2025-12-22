import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import 'service_providers.dart';

// Expansion Filter Options
enum ExpansionFilter {
  baseGames,      // Default - show only base games and standalone games (no expansions)
  onlyExpansions, // Show only expansions
  all,            // Show everything
}

// Helper function to check if a game matches the search query
bool gameMatchesSearch(
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
