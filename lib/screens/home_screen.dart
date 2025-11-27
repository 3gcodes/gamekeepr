import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/game.dart';
import '../models/game_with_play_info.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'game_details_screen.dart';
import 'settings_screen.dart';
import 'nfc_scan_screen.dart';
import 'nfc_record_play_screen.dart';
import 'write_shelf_tag_screen.dart';
import 'bgg_search_screen.dart';
import 'wishlist_screen.dart';
import 'scheduled_games_screen.dart';
import 'move_games_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncGames() async {
    final username = ref.read(bggUsernameProvider);

    if (username.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your BGG username in settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Get API token from shared preferences directly
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final apiToken = prefs.getString('bgg_api_token') ?? '';

    if (apiToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your BGG API token in settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show blocking progress modal
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'Syncing collection...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      await ref.read(gamesProvider.notifier).syncFromBgg(username, apiToken);
      ref.read(syncStatusProvider.notifier).state = SyncStatus.success;

      // Close the progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collection synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;

      // Close the progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const FilterBottomSheet(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.casino,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  'Game Keepr',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Wishlist'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Scheduled Games'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduledGamesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move),
            title: const Text('Move Game(s)'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MoveGamesScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle(int currentTab) {
    switch (currentTab) {
      case 0:
        return 'Collection';
      case 1:
        return 'All Games';
      case 2:
        return 'Recently Played';
      default:
        return 'Game Keepr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentViewTabProvider);
    final filteredGames = ref.watch(filteredGamesProvider);
    final allGames = ref.watch(allGamesFilteredProvider);
    final filteredRecentlyPlayed = ref.watch(filteredRecentlyPlayedGamesProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isSyncing = syncStatus == SyncStatus.syncing;
    final expansionFilter = ref.watch(expansionFilterProvider);
    final hasActiveFilters = expansionFilter != ExpansionFilter.baseGames;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(currentTab)),
        actions: [
          // Filter button - show on Collection and All Games tabs
          if (currentTab == 0 || currentTab == 1)
            IconButton(
              icon: Badge(
                isLabelVisible: hasActiveFilters,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: _showFilterBottomSheet,
              tooltip: 'Filter',
            ),
          // Direct Scan Tag button
          IconButton(
            icon: const Icon(Icons.nfc),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NfcScanScreen()),
              );
            },
            tooltip: 'Scan Tag',
          ),
          // Other NFC options menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.edit_note),
            tooltip: 'NFC Actions',
            onSelected: (value) {
              if (value == 'record_play') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NfcRecordPlayScreen()),
                );
              } else if (value == 'write_shelf') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WriteShelfTagScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'record_play',
                child: Row(
                  children: [
                    Icon(Icons.event_available),
                    SizedBox(width: 12),
                    Text('Record Play'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'write_shelf',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 12),
                    Text('Write Shelf Tag'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: isSyncing ? null : _syncGames,
            tooltip: 'Sync from BGG',
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside the text field
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
                  // Dismiss keyboard when user presses "Done"
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Search games...',
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
            child: _buildTabContent(currentTab, filteredGames, allGames, filteredRecentlyPlayed),
          ),
        ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        onTap: (index) {
          ref.read(currentViewTabProvider.notifier).state = index;
          // Clear search when switching tabs
          _searchController.clear();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.casino),
            label: 'Collection',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.games),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recently Played',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    int currentTab,
    AsyncValue<List<Game>> filteredGames,
    AsyncValue<List<Game>> allGames,
    AsyncValue<List<GameWithPlayInfo>> filteredRecentlyPlayed,
  ) {
    switch (currentTab) {
      case 0:
        return _buildCollectionView(filteredGames);
      case 1:
        return _buildAllGamesView(allGames);
      case 2:
        return _buildRecentlyPlayedView(filteredRecentlyPlayed);
      default:
        return _buildCollectionView(filteredGames);
    }
  }

  Widget _buildCollectionView(AsyncValue<List<Game>> filteredGames) {
    return filteredGames.when(
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.casino_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty
                      ? 'No games in collection'
                      : 'No games found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                if (_searchController.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap the sync button to load your collection',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BggSearchScreen(
                            initialQuery: _searchController.text,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search BGG'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return _GameListItem(
              game: game,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailsScreen(game: game),
                  ),
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
                ref.read(gamesProvider.notifier).loadGames();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllGamesView(AsyncValue<List<Game>> allGames) {
    return allGames.when(
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.games_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty
                      ? 'No games yet'
                      : 'No games found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                if (_searchController.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sync your collection or search BGG to add games',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BggSearchScreen(
                            initialQuery: _searchController.text,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search BGG'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return _GameListItem(
              game: game,
              showOwnedIndicator: true,
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
                ref.read(gamesProvider.notifier).loadGames();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedView(AsyncValue<List<GameWithPlayInfo>> filteredRecentlyPlayed) {
    return filteredRecentlyPlayed.when(
      data: (gamesWithPlayInfo) {
        if (gamesWithPlayInfo.isEmpty) {
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
                  _searchController.text.isEmpty
                      ? 'No games played yet'
                      : 'No played games found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                if (_searchController.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Record your first play to see it here',
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: gamesWithPlayInfo.length,
          itemBuilder: (context, index) {
            final gameWithInfo = gamesWithPlayInfo[index];
            return _RecentlyPlayedGameListItem(
              gameWithPlayInfo: gameWithInfo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailsScreen(game: gameWithInfo.game),
                  ),
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
                ref.read(recentlyPlayedGamesProvider.notifier).loadRecentlyPlayedGames();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameListItem extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final bool showOwnedIndicator;

  const _GameListItem({
    required this.game,
    required this.onTap,
    this.showOwnedIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
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
                    if (game.yearPublished != null)
                      Text(
                        'Year: ${game.yearPublished}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
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
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
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
                    if (game.location != null && game.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.blue[600]),
                          const SizedBox(width: 4),
                          Text(
                            game.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (game.hasNfcTag) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.nfc, size: 14, color: Colors.purple[600]),
                          const SizedBox(width: 4),
                          Text(
                            'NFC Tag',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showOwnedIndicator) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            game.owned ? Icons.check_circle : Icons.remove_circle_outline,
                            size: 14,
                            color: game.owned ? Colors.green[600] : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            game.owned ? 'Owned' : 'Not Owned',
                            style: TextStyle(
                              fontSize: 12,
                              color: game.owned ? Colors.green[600] : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _RecentlyPlayedGameListItem extends StatelessWidget {
  final GameWithPlayInfo gameWithPlayInfo;
  final VoidCallback onTap;

  const _RecentlyPlayedGameListItem({
    required this.gameWithPlayInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final game = gameWithPlayInfo.game;
    final lastPlayed = gameWithPlayInfo.lastPlayed;
    final playCount = gameWithPlayInfo.playCount;
    final wins = gameWithPlayInfo.wins;
    final losses = gameWithPlayInfo.losses;

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
                          child: const Icon(Icons.casino, size: 30),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.casino, size: 30),
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
                        Icon(Icons.event, size: 14, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Last played: ${DateFormat('MMM d, yyyy').format(lastPlayed)}',
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
                        if (wins > 0 || losses > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '($wins-$losses)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(width: 16),
                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          game.playersInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (game.location != null && game.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.blue[600]),
                          const SizedBox(width: 4),
                          Text(
                            game.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (game.hasNfcTag) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.nfc, size: 14, color: Colors.purple[600]),
                          const SizedBox(width: 4),
                          Text(
                            'NFC Tag',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
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

