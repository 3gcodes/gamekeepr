import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_providers.dart';
import '../providers/collectibles_provider.dart';
import '../models/game.dart';
import '../models/collectible.dart';
import '../constants/location_constants.dart';
import 'game_details_screen.dart';
import 'collectible_details_screen.dart';

/// Screen showing all games on a specific shelf
class ShelfViewScreen extends ConsumerWidget {
  final String shelf;

  const ShelfViewScreen({
    super.key,
    required this.shelf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allGamesAsync = ref.watch(gamesProvider);
    final allCollectiblesAsync = ref.watch(collectiblesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Shelf $shelf'),
      ),
      body: allGamesAsync.when(
        data: (allGames) {
          // Filter games that start with this shelf letter
          final shelfGames = allGames
              .where((game) =>
                  game.location != null &&
                  game.location!.toUpperCase().startsWith(shelf.toUpperCase()))
              .toList();

          // Filter collectibles that start with this shelf letter
          final shelfCollectibles = allCollectiblesAsync.maybeWhen(
            data: (collectibles) => collectibles
                .where((collectible) =>
                    collectible.location != null &&
                    collectible.location!.toUpperCase().startsWith(shelf.toUpperCase()))
                .toList(),
            orElse: () => <Collectible>[],
          );

          if (shelfGames.isEmpty && shelfCollectibles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shelves,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nothing on Shelf $shelf',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assign games or collectibles to this shelf to see them here',
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

          // Group games by bay
          final gamesByBay = <int, List<Game>>{};
          for (final game in shelfGames) {
            final locationParts = LocationConstants.parseLocation(game.location!);
            if (locationParts != null) {
              gamesByBay.putIfAbsent(locationParts.bay, () => []).add(game);
            }
          }

          // Group collectibles by bay
          final collectiblesByBay = <int, List<Collectible>>{};
          for (final collectible in shelfCollectibles) {
            final locationParts = LocationConstants.parseLocation(collectible.location!);
            if (locationParts != null) {
              collectiblesByBay.putIfAbsent(locationParts.bay, () => []).add(collectible);
            }
          }

          // Get all unique bays from both games and collectibles
          final allBays = {...gamesByBay.keys, ...collectiblesByBay.keys}.toList()..sort();

          return Column(
            children: [
              // Shelf summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    Icon(Icons.shelves, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (shelfGames.isNotEmpty)
                            Text(
                              '${shelfGames.length} ${shelfGames.length == 1 ? 'game' : 'games'}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          if (shelfGames.isNotEmpty && shelfCollectibles.isNotEmpty)
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          if (shelfCollectibles.isNotEmpty)
                            Text(
                              '${shelfCollectibles.length} collectible${shelfCollectibles.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Items list grouped by bay
              Expanded(
                child: ListView.builder(
                  itemCount: allBays.length,
                  itemBuilder: (context, index) {
                    final bay = allBays[index];
                    final gamesInBay = gamesByBay[bay] ?? [];
                    final collectiblesInBay = collectiblesByBay[bay] ?? [];
                    final totalItemsInBay = gamesInBay.length + collectiblesInBay.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bay header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: Colors.grey[200],
                          child: Row(
                            children: [
                              Icon(Icons.grid_view, size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Bay $bay',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$totalItemsInBay',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Games in this bay
                        if (gamesInBay.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                            child: Text(
                              'Games (${gamesInBay.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ...gamesInBay.map((game) => _ShelfGameListItem(
                              game: game,
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
                            )),
                        // Collectibles in this bay
                        if (collectiblesInBay.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              left: 16,
                              top: gamesInBay.isNotEmpty ? 12 : 8,
                              bottom: 4,
                            ),
                            child: Text(
                              'Collectibles (${collectiblesInBay.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ...collectiblesInBay.map((collectible) => _ShelfCollectibleListItem(
                              collectible: collectible,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CollectibleDetailsScreen(collectible: collectible),
                                  ),
                                );
                              },
                            )),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading games: $error'),
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
      ),
    );
  }
}

class _ShelfGameListItem extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const _ShelfGameListItem({
    required this.game,
    required this.onTap,
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
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          game.location ?? 'No location',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

class _ShelfCollectibleListItem extends StatelessWidget {
  final Collectible collectible;
  final VoidCallback onTap;

  const _ShelfCollectibleListItem({
    required this.collectible,
    required this.onTap,
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
              // Image/Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: collectible.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(collectible.imageUrl!),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.category,
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    : Icon(Icons.category, color: Colors.grey[400]),
              ),
              const SizedBox(width: 12),
              // Collectible Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collectible.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.deepPurple[600]),
                        const SizedBox(width: 4),
                        Text(
                          collectible.location ?? 'No location',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.deepPurple[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(
                            collectible.typeDisplayName,
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        ),
                        if (collectible.quantity > 1)
                          Chip(
                            label: Text(
                              'Qty: ${collectible.quantity}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          ),
                        if (collectible.type == CollectibleType.MINIATURE && collectible.painted)
                          Chip(
                            label: const Text(
                              'Painted',
                              style: TextStyle(fontSize: 11),
                            ),
                            avatar: const Icon(Icons.check_circle, size: 14, color: Colors.green),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
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

