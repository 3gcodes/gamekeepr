import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/collectible.dart';
import '../models/game.dart';
import '../providers/collectibles_provider.dart';
import '../providers/games_provider.dart';
import '../providers/service_providers.dart';
import '../widgets/location_picker.dart';
import 'add_collectible_screen.dart';
import 'game_details_screen.dart';

class CollectibleDetailsScreen extends ConsumerStatefulWidget {
  final Collectible collectible;

  const CollectibleDetailsScreen({
    super.key,
    required this.collectible,
  });

  @override
  ConsumerState<CollectibleDetailsScreen> createState() => _CollectibleDetailsScreenState();
}

class _CollectibleDetailsScreenState extends ConsumerState<CollectibleDetailsScreen> {
  late Collectible _currentCollectible;

  @override
  void initState() {
    super.initState();
    _currentCollectible = widget.collectible;
  }

  Future<void> _refreshCollectible() async {
    if (_currentCollectible.id == null) return;
    final updated = await ref.read(collectiblesProvider.notifier).getCollectibleById(_currentCollectible.id!);
    if (updated != null && mounted) {
      setState(() {
        _currentCollectible = updated;
      });
    }
  }

  Future<void> _writeNfcTag() async {
    if (_currentCollectible.id == null) return;

    final nfcService = ref.read(nfcServiceProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Hold your iPhone near the NFC tag...'),
          ],
        ),
      ),
    );

    final success = await nfcService.writeCollectibleId(_currentCollectible.id!);

    if (!mounted) return;
    Navigator.of(context).pop(); // Close dialog

    if (success) {
      await ref.read(collectiblesProvider.notifier).updateCollectibleHasNfcTag(_currentCollectible.id!, true);
      await _refreshCollectible();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('NFC tag written successfully!')),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Failed to write NFC tag')),
      );
    }
  }

  Future<void> _deleteCollectible() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collectible'),
        content: Text('Are you sure you want to delete "${_currentCollectible.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentCollectible.id != null) {
      await ref.read(collectiblesProvider.notifier).deleteCollectible(_currentCollectible.id!);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesProvider);
    Game? associatedGame;
    if (_currentCollectible.gameId != null) {
      gamesAsync.whenData((games) {
        try {
          associatedGame = games.firstWhere((g) => g.id == _currentCollectible.gameId);
        } catch (e) {
          // Game not found
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCollectible.name),
        actions: [
          if (_currentCollectible.id != null)
            IconButton(
              icon: const Icon(Icons.nfc),
              onPressed: _writeNfcTag,
              tooltip: 'Write NFC Tag',
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCollectibleScreen(collectible: _currentCollectible),
                ),
              );
              await _refreshCollectible();
            },
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteCollectible,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (_currentCollectible.imageUrl != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: _currentCollectible.imageUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.category, size: 64),
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category, size: 64, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 24),

            // Type badge
            _buildInfoSection(
              'Type',
              Chip(
                label: Text(_currentCollectible.typeDisplayName),
                backgroundColor: Colors.deepPurple[100],
              ),
            ),

            // Manufacturer
            if (_currentCollectible.manufacturer != null)
              _buildInfoSection('Manufacturer', Text(_currentCollectible.manufacturer!)),

            // Quantity
            _buildInfoSection('Quantity', Text('${_currentCollectible.quantity}')),

            // Painted status (for miniatures)
            if (_currentCollectible.type == CollectibleType.MINIATURE)
              _buildInfoSection(
                'Painted',
                SwitchListTile(
                  value: _currentCollectible.painted,
                  onChanged: (value) async {
                    if (_currentCollectible.id != null) {
                      await ref.read(collectiblesProvider.notifier).updateCollectiblePainted(
                        _currentCollectible.id!,
                        value,
                      );
                      await _refreshCollectible();
                    }
                  },
                  title: Text(_currentCollectible.painted ? 'Painted' : 'Unpainted'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),

            // Description
            if (_currentCollectible.description != null)
              _buildInfoSection('Description', Text(_currentCollectible.description!)),

            // Associated Game
            if (associatedGame != null) ...[
              const Divider(height: 32),
              const Text(
                'Associated Game',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: associatedGame!.thumbnailUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: associatedGame!.thumbnailUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : null,
                  title: Text(associatedGame!.name),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameDetailsScreen(
                          game: associatedGame!,
                          isOwned: associatedGame!.owned,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Location
            const Divider(height: 32),
            const Text(
              'Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LocationPicker(
              initialLocation: _currentCollectible.location,
              onLocationSelected: (location) async {
                if (_currentCollectible.id != null) {
                  await ref.read(collectiblesProvider.notifier).updateCollectibleLocation(
                    _currentCollectible.id!,
                    location,
                  );
                  await _refreshCollectible();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Location set to $location')),
                  );
                }
              },
            ),

            // NFC Tag status
            if (_currentCollectible.hasNfcTag) ...[
              const SizedBox(height: 16),
              const Card(
                color: Colors.green,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.nfc, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'NFC Tag Assigned',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        content,
        const SizedBox(height: 16),
      ],
    );
  }
}
