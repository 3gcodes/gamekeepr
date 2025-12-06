import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import '../providers/app_providers.dart';
import 'game_details_screen.dart';

class BggSearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const BggSearchScreen({
    super.key,
    required this.initialQuery,
  });

  @override
  ConsumerState<BggSearchScreen> createState() => _BggSearchScreenState();
}

class _BggSearchScreenState extends ConsumerState<BggSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _error;

  // Lazy loading state
  final Set<int> _loadedThumbnails = {};
  final Set<int> _pendingThumbnails = {};
  Timer? _thumbnailFetchTimer;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      _searchBgg();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _thumbnailFetchTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchBgg() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _loadedThumbnails.clear();
      _pendingThumbnails.clear();
    });

    try {
      // Ensure token is loaded before using the service
      final bggService = ref.read(bggServiceProvider);
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final token = prefs.getString('bgg_api_token') ?? '';
      if (token.isNotEmpty) {
        bggService.setBearerToken(token);
      }

      final results = await bggService.searchGames(query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      // Mark initially loaded thumbnails
      for (final result in results) {
        if (result['thumbnailUrl'] != null) {
          _loadedThumbnails.add(result['id'] as int);
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  /// Request thumbnail loading for a specific game ID
  void _requestThumbnail(int gameId) {
    // Skip if already loaded or pending
    if (_loadedThumbnails.contains(gameId) || _pendingThumbnails.contains(gameId)) {
      return;
    }

    _pendingThumbnails.add(gameId);

    // Cancel existing timer and start a new one to batch requests
    _thumbnailFetchTimer?.cancel();
    _thumbnailFetchTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchPendingThumbnails();
    });
  }

  /// Fetch thumbnails for all pending game IDs
  Future<void> _fetchPendingThumbnails() async {
    if (_pendingThumbnails.isEmpty) return;

    final idsToFetch = _pendingThumbnails.toList();
    _pendingThumbnails.clear();

    try {
      final bggService = ref.read(bggServiceProvider);
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final token = prefs.getString('bgg_api_token') ?? '';
      if (token.isNotEmpty) {
        bggService.setBearerToken(token);
      }

      print('🖼️ Lazy loading thumbnails for ${idsToFetch.length} games...');
      final thumbnails = await bggService.fetchThumbnails(idsToFetch);

      // Update search results with the new thumbnails
      if (mounted) {
        setState(() {
          for (final result in _searchResults) {
            final id = result['id'] as int;
            if (thumbnails.containsKey(id) && thumbnails[id] != null) {
              result['thumbnailUrl'] = thumbnails[id];
              _loadedThumbnails.add(id);
            }
          }
        });
      }
    } catch (e) {
      print('⚠️ Failed to lazy load thumbnails: $e');
      // Don't show error to user for lazy loading failures
    }
  }

  /// Add a game to collection from search results
  Future<void> _addGameToCollection(int bggId, String gameName) async {
    try {
      // Ensure token is loaded before using the service
      final bggService = ref.read(bggServiceProvider);
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final token = prefs.getString('bgg_api_token') ?? '';
      if (token.isNotEmpty) {
        bggService.setBearerToken(token);
      }

      final gamesNotifier = ref.read(gamesProvider.notifier);

      // Check if game already exists in database
      var existingGame = await gamesNotifier.getGameByBggId(bggId);

      if (existingGame != null && existingGame.owned) {
        // Game is already owned
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$gameName is already in your collection'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      Game gameToAdd;

      if (existingGame != null) {
        // Game exists but not owned - just toggle ownership
        gameToAdd = existingGame;
      } else {
        // Fetch from BGG and save to database
        final game = await bggService.fetchGameDetails(bggId);
        gameToAdd = await gamesNotifier.saveGameFromBggSearch(game);
      }

      // Mark as owned
      await gamesNotifier.toggleOwned(gameToAdd.id!, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $gameName to your collection'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailsScreen(
                      game: gameToAdd.copyWith(owned: true),
                      isOwned: true,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewGameDetails(int bggId, String gameName) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Ensure token is loaded before using the service
      final bggService = ref.read(bggServiceProvider);
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final token = prefs.getString('bgg_api_token') ?? '';
      if (token.isNotEmpty) {
        bggService.setBearerToken(token);
      }

      final gamesNotifier = ref.read(gamesProvider.notifier);

      // First check if game already exists in database
      var existingGame = await gamesNotifier.getGameByBggId(bggId);

      Game gameToShow;
      bool isOwned;

      if (existingGame != null) {
        // Game already exists, use existing data
        gameToShow = existingGame;
        isOwned = existingGame.owned;
      } else {
        // Fetch from BGG and save to database (as not owned)
        final game = await bggService.fetchGameDetails(bggId);
        gameToShow = await gamesNotifier.saveGameFromBggSearch(game);
        isOwned = false;
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameDetailsScreen(
              game: gameToShow,
              isOwned: isOwned,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading game details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search BGG'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchBgg(),
              decoration: InputDecoration(
                hintText: 'Search BoardGameGeek...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Search button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _searchBgg,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchBgg,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Enter a game name to search'
                  : 'No results found',
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
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final name = result['name'] as String;
        final year = result['year'] as int?;
        final bggId = result['id'] as int;
        final thumbnailUrl = result['thumbnailUrl'] as String?;

        // Request thumbnail if not already loaded
        if (thumbnailUrl == null) {
          _requestThumbnail(bggId);
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      thumbnailUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.videogame_asset,
                      color: Colors.grey,
                    ),
                  ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: year != null ? Text('Year: $year') : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                  tooltip: 'Add to collection',
                  onPressed: () => _addGameToCollection(bggId, name),
                ),
                const Icon(Icons.arrow_forward),
              ],
            ),
            onTap: () => _viewGameDetails(bggId, name),
          ),
        );
      },
    );
  }
}
