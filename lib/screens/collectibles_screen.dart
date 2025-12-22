import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/collectibles_provider.dart';
import '../providers/games_provider.dart';
import '../models/collectible.dart';
import '../models/game.dart';
import 'collectible_details_screen.dart';
import 'add_collectible_screen.dart';

class CollectiblesScreen extends ConsumerStatefulWidget {
  const CollectiblesScreen({super.key});

  @override
  ConsumerState<CollectiblesScreen> createState() => _CollectiblesScreenState();
}

class _CollectiblesScreenState extends ConsumerState<CollectiblesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(collectiblesSearchProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectibles = ref.watch(filteredCollectiblesByTypeProvider);
    final selectedType = ref.watch(selectedCollectibleTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collectibles'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_collectible_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddCollectibleScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
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
                  hintText: 'Search collectibles...',
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
            // Type filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: selectedType == null,
                    onSelected: (_) {
                      ref.read(selectedCollectibleTypeProvider.notifier).state = null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Miniatures'),
                    selected: selectedType == CollectibleType.MINIATURE,
                    onSelected: (_) {
                      ref.read(selectedCollectibleTypeProvider.notifier).state =
                        selectedType == CollectibleType.MINIATURE ? null : CollectibleType.MINIATURE;
                    },
                  ),
                  // Future type filters can be added here
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildCollectiblesView(collectibles),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectiblesView(AsyncValue<List<Collectible>> collectibles) {
    return collectibles.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty
                      ? 'No collectibles yet'
                      : 'No collectibles found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                if (_searchController.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first collectible',
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
          itemCount: items.length,
          itemBuilder: (context, index) {
            final collectible = items[index];
            return _CollectibleListItem(
              collectible: collectible,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CollectibleDetailsScreen(collectible: collectible),
                  ),
                );
                // Refresh collectibles after returning
                ref.read(collectiblesProvider.notifier).loadCollectibles();
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
                ref.read(collectiblesProvider.notifier).loadCollectibles();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectibleListItem extends ConsumerWidget {
  final Collectible collectible;
  final VoidCallback onTap;

  const _CollectibleListItem({
    required this.collectible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get associated game if any
    final gamesAsync = ref.watch(gamesProvider);
    Game? associatedGame;
    if (collectible.gameId != null) {
      gamesAsync.whenData((games) {
        try {
          associatedGame = games.firstWhere((g) => g.id == collectible.gameId);
        } catch (e) {
          // Game not found
        }
      });
    }

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
              // Image placeholder
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
                            size: 32,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.category,
                        color: Colors.grey[400],
                        size: 32,
                      ),
              ),
              const SizedBox(width: 12),
              // Content
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
                    // Type badge
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(
                            collectible.typeDisplayName,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.deepPurple[100],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        ),
                        if (collectible.quantity > 1)
                          Chip(
                            label: Text(
                              'Qty: ${collectible.quantity}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.blue[100],
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          ),
                        if (collectible.type == CollectibleType.MINIATURE && collectible.painted)
                          Chip(
                            label: const Text(
                              'Painted',
                              style: TextStyle(fontSize: 12),
                            ),
                            avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            backgroundColor: Colors.green[100],
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          ),
                      ],
                    ),
                    if (collectible.manufacturer != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        collectible.manufacturer!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (associatedGame != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.videogame_asset, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              associatedGame!.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (collectible.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            collectible.location!,
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
