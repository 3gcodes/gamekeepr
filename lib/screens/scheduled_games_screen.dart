import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/game.dart';
import '../models/scheduled_game.dart';
import 'game_details_screen.dart';

class ScheduledGamesScreen extends ConsumerStatefulWidget {
  const ScheduledGamesScreen({super.key});

  @override
  ConsumerState<ScheduledGamesScreen> createState() => _ScheduledGamesScreenState();
}

class _ScheduledGamesScreenState extends ConsumerState<ScheduledGamesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduledGames = ref.watch(scheduledGamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Games'),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Search scheduled games...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildScheduledGamesView(scheduledGames),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledGamesView(AsyncValue<List<ScheduledGame>> scheduledGames) {
    return scheduledGames.when(
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No scheduled games',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Schedule a game from the game details page',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<_ScheduledGameWithDetails>>(
          future: _loadGamesWithDetails(games),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading games: ${snapshot.error}'),
                  ],
                ),
              );
            }

            final gamesWithDetails = snapshot.data ?? [];

            // Filter by search query
            final filteredGames = _searchQuery.isEmpty
                ? gamesWithDetails
                : gamesWithDetails.where((item) {
                    return item.game.name.toLowerCase().contains(_searchQuery);
                  }).toList();

            if (filteredGames.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No games found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: filteredGames.length,
              itemBuilder: (context, index) {
                final item = filteredGames[index];
                return _ScheduledGameItem(
                  scheduledGame: item.scheduledGame,
                  game: item.game,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameDetailsScreen(
                          game: item.game,
                          isOwned: item.game.owned,
                        ),
                      ),
                    );
                  },
                );
              },
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(scheduledGamesProvider.notifier).loadScheduledGames();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_ScheduledGameWithDetails>> _loadGamesWithDetails(List<ScheduledGame> scheduledGames) async {
    final db = ref.read(databaseServiceProvider);
    final List<_ScheduledGameWithDetails> result = [];

    for (final scheduledGame in scheduledGames) {
      final game = await db.getGameById(scheduledGame.gameId);
      if (game != null) {
        result.add(_ScheduledGameWithDetails(
          scheduledGame: scheduledGame,
          game: game,
        ));
      }
    }

    return result;
  }
}

class _ScheduledGameWithDetails {
  final ScheduledGame scheduledGame;
  final Game game;

  _ScheduledGameWithDetails({
    required this.scheduledGame,
    required this.game,
  });
}

class _ScheduledGameItem extends StatelessWidget {
  final ScheduledGame scheduledGame;
  final Game game;
  final VoidCallback onTap;

  const _ScheduledGameItem({
    required this.scheduledGame,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(scheduledGame.scheduledDateTime);
    final timeStr = DateFormat('h:mm a').format(scheduledGame.scheduledDateTime);
    final now = DateTime.now();
    final isToday = scheduledGame.scheduledDateTime.year == now.year &&
        scheduledGame.scheduledDateTime.month == now.month &&
        scheduledGame.scheduledDateTime.day == now.day;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: game.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: game.thumbnailUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.casino),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.casino),
                      ),
              ),
              const SizedBox(width: 12),
              // Game Info
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
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 14,
                          color: isToday ? Colors.orange[600] : Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isToday ? 'Today at $timeStr' : dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday ? Colors.orange[600] : Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (!isToday) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (scheduledGame.location != null && scheduledGame.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              scheduledGame.location!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          game.playersInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          game.playtimeInfo,
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
  }
}
