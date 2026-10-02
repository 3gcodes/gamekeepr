import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/recently_played_providers.dart';
import '../providers/search_providers.dart';
import '../screens/game_details_screen.dart';

/// Displays the list of recently played games. Used both as a top-level tab
/// and anywhere else the play history needs to be shown.
class RecentlyPlayedView extends ConsumerWidget {
  const RecentlyPlayedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Search spans all of time, so the date-range selector is hidden while searching.
    final isSearching = ref.watch(searchQueryProvider).isNotEmpty;

    return Column(
      children: [
        if (!isSearching) _buildRangeSelector(context, ref),
        Expanded(child: _buildList(context, ref, isSearching)),
      ],
    );
  }

  Widget _buildRangeSelector(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(recentlyPlayedRangeProvider);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final range in RecentlyPlayedRange.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(range.label),
                selected: selected == range,
                onSelected: (_) {
                  ref.read(recentlyPlayedRangeProvider.notifier).state = range;
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, bool isSearching) {
    final recentlyPlayed = ref.watch(filteredRecentlyPlayedGamesProvider);
    final rangeLabel = ref.watch(recentlyPlayedRangeProvider).label;

    return recentlyPlayed.when(
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  isSearching
                      ? 'No games found'
                      : 'No games played · $rangeLabel',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                if (!isSearching) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Try a different range or log a play!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: games.length,
          itemBuilder: (context, index) {
            final gameWithPlayInfo = games[index];
            final game = gameWithPlayInfo.game;
            final lastPlayed = gameWithPlayInfo.lastPlayed;
            final playCount = gameWithPlayInfo.playCount;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameDetailsScreen(
                        game: game,
                        isOwned: game.owned,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Game thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: game.thumbnailUrl != null && game.thumbnailUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: game.thumbnailUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.casino,
                                    size: 32,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.casino,
                                  size: 32,
                                  color: Colors.grey[400],
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Game info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.event, size: 14, color: Colors.green[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Last: ${DateFormat('MMM d, yyyy').format(lastPlayed)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.bar_chart, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '$playCount ${playCount == 1 ? 'play' : 'plays'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
    );
  }
}
