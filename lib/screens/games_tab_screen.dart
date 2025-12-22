import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_providers.dart';
import '../models/game.dart';
import 'game_details_screen.dart';
import 'bgg_search_screen.dart';

class GamesTabScreen extends ConsumerStatefulWidget {
  const GamesTabScreen({super.key});

  @override
  ConsumerState<GamesTabScreen> createState() => _GamesTabScreenState();
}

class _GamesTabScreenState extends ConsumerState<GamesTabScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(gamesSubTabIndexProvider);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(gamesSubTabIndexProvider.notifier).state = _tabController.index;
        // Clear search when switching tabs
        _searchController.clear();
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });

    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    final gameNotifier = ref.read(gamesProvider.notifier);
    final username = ref.read(bggUsernameProvider);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final apiToken = prefs.getString('bgg_api_token') ?? '';

    if (username.isEmpty || apiToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your BGG username and API token in settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      await gameNotifier.syncFromBgg(username, apiToken);
      if (mounted) {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.success;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Games synced successfully!')),
        );
        // Reset after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Collection'),
            Tab(text: 'Wishlist'),
            Tab(text: 'Saved'),
          ],
        ),
        actions: [
          if (syncStatus == SyncStatus.syncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.sync,
                color: syncStatus == SyncStatus.success
                    ? Colors.green
                    : syncStatus == SyncStatus.error
                        ? Colors.red
                        : null,
              ),
              onPressed: _handleSync,
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
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
            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCollectionView(),
                  _buildWishlistView(),
                  _buildSavedForLaterView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionView() {
    final filteredGames = ref.watch(filteredGamesProvider);

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
            return _buildGameListItem(game, isOwned: game.owned);
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

  Widget _buildWishlistView() {
    final wishlist = ref.watch(wishlistProvider);

    return wishlist.when(
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty
                      ? 'Your wishlist is empty'
                      : 'No games found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                if (_searchController.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mark games as favorites to add them here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
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
            return _buildGameListItem(game, isOwned: game.owned);
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

  Widget _buildSavedForLaterView() {
    final savedForLater = ref.watch(savedForLaterProvider);

    return savedForLater.when(
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty
                      ? 'No games saved for later'
                      : 'No games found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                if (_searchController.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Save games you want to track for later',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
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
            return _buildGameListItem(game, isOwned: game.owned);
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

  Widget _buildGameListItem(Game game, {required bool isOwned}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailsScreen(
                game: game,
                isOwned: isOwned,
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
              // Thumbnail
              if (game.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: game.thumbnailUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.casino, size: 40),
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.casino, size: 40),
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
                    if (game.yearPublished != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Published: ${game.yearPublished}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (!isOwned) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Not Owned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                    if (game.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            game.location!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
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
