import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../models/play.dart';
import '../providers/app_providers.dart';
import 'package:intl/intl.dart';

class GameDetailsScreen extends ConsumerStatefulWidget {
  final Game game;

  const GameDetailsScreen({
    super.key,
    required this.game,
  });

  @override
  ConsumerState<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends ConsumerState<GameDetailsScreen> {
  late TextEditingController _locationController;
  Game? _detailedGame;
  bool _isLoadingDetails = false;
  List<Play> _plays = [];
  bool _isLoadingPlays = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.game.location ?? '');
    _detailedGame = widget.game;

    // Skip fetching details - BGG XML API v2 authentication is not accessible
    // We already have essential info (name, year, images) from collection sync
    // if (_needsDetails(widget.game)) {
    //   _fetchGameDetails();
    // }

    // Load play history for this game
    _loadPlays();
  }

  bool _needsDetails(Game game) {
    // If we don't have description or player counts, we need details
    return game.description == null ||
           game.minPlayers == null ||
           game.maxPlayers == null;
  }

  Future<void> _fetchGameDetails() async {
    if (_isLoadingDetails) return;

    setState(() {
      _isLoadingDetails = true;
    });

    try {
      print('📖 Fetching details for game ${widget.game.bggId}...');

      final bggService = ref.read(bggServiceProvider);
      final detailedGame = await bggService.fetchGameDetails(widget.game.bggId);

      // Preserve the database ID and location
      final updatedGame = detailedGame.copyWith(
        id: widget.game.id,
        location: widget.game.location,
      );

      // Update database
      final db = ref.read(databaseServiceProvider);
      await db.updateGame(updatedGame);

      setState(() {
        _detailedGame = updatedGame;
        _isLoadingDetails = false;
      });

      print('✅ Fetched and saved details for ${widget.game.name}');
    } catch (e) {
      print('❌ Error fetching game details: $e');
      setState(() {
        _isLoadingDetails = false;
      });
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load full details: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadPlays() async {
    if (widget.game.id == null) return;

    setState(() {
      _isLoadingPlays = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final plays = await db.getPlaysForGame(widget.game.id!);

      setState(() {
        _plays = plays;
        _isLoadingPlays = false;
      });
    } catch (e) {
      print('❌ Error loading plays: $e');
      setState(() {
        _isLoadingPlays = false;
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveLocation() async {
    final location = _locationController.text.trim();

    try {
      await ref.read(gamesProvider.notifier).updateGameLocation(
            widget.game.id!,
            location,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recordPlay() async {
    if (widget.game.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show date picker
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    try {
      final db = ref.read(databaseServiceProvider);
      final play = Play(
        gameId: widget.game.id!,
        datePlayed: selectedDate,
      );

      await db.insertPlay(play);

      // Reload plays
      await _loadPlays();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Play recorded for ${DateFormat('MMM d, yyyy').format(selectedDate)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording play: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePlay(int playId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Play'),
        content: const Text('Are you sure you want to delete this play record?'),
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

    if (confirmed == true) {
      try {
        final db = ref.read(databaseServiceProvider);
        await db.deletePlay(playId);

        // Reload plays
        await _loadPlays();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Play deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting play: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _writeToNfc() async {
    if (widget.game.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final nfcService = ref.read(nfcServiceProvider);

    // Skip availability check - isAvailable() has bugs on some iOS versions
    // The native dialog appearing confirms NFC is actually working
    print('📱 Skipping NFC availability check...');

    // Show dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Write to NFC Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Hold your device near the NFC tag for ${widget.game.name}'),
            ],
          ),
        ),
      );
    }

    print('📱 Dialog shown, about to start NFC write...');

    // Small delay to ensure dialog is visible
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Use BGG ID for the NFC tag
      print('📱 Calling writeGameId for BGG ID: ${widget.game.bggId}');
      final success = await nfcService.writeGameId(widget.game.bggId);
      print('📱 writeGameId returned: $success');

      if (mounted) {
        Navigator.pop(context); // Close dialog

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game ID written to NFC tag'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to write to NFC tag'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _detailedGame ?? widget.game;

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        actions: [
          if (_isLoadingDetails)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.nfc),
            onPressed: _writeToNfc,
            tooltip: 'Write to NFC Tag',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game Image
            if (game.imageUrl != null)
              CachedNetworkImage(
                imageUrl: game.imageUrl!,
                height: 300,
                fit: BoxFit.contain,
                placeholder: (context, url) => Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Icon(Icons.casino, size: 64),
                ),
              )
            else
              Container(
                height: 300,
                color: Colors.grey[300],
                child: const Icon(Icons.casino, size: 64),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    game.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Basic Info
                  if (game.yearPublished != null)
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Year Published',
                      value: game.yearPublished.toString(),
                    ),

                  _InfoRow(
                    icon: Icons.people,
                    label: 'Players',
                    value: game.playersInfo,
                  ),

                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Playtime',
                    value: game.playtimeInfo,
                  ),

                  if (game.averageRating != null)
                    _InfoRow(
                      icon: Icons.star,
                      label: 'Rating',
                      value: game.averageRating!.toStringAsFixed(2),
                    ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Location Editor
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Shelf B, Bay 8',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveLocation,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Location'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Play Recording Section
                  Text(
                    'Play History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _recordPlay,
                      icon: const Icon(Icons.add),
                      label: const Text('Record Play'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Play History List
                  if (_isLoadingPlays)
                    const Center(child: CircularProgressIndicator())
                  else if (_plays.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No plays recorded yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _plays.map((play) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.event, color: Colors.blue),
                            title: Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(play.datePlayed),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              'Recorded ${DateFormat('MMM d, yyyy').format(play.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePlay(play.id!),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Description
                  if (game.description != null &&
                      game.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stripHtmlTags(game.description!),
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&quot;', '"');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
