import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../models/play.dart';
import '../providers/app_providers.dart';
import '../widgets/location_picker.dart';
import 'package:intl/intl.dart';

class GameDetailsScreen extends ConsumerStatefulWidget {
  final Game game;
  final bool isOwned;

  const GameDetailsScreen({
    super.key,
    required this.game,
    this.isOwned = true, // Default to owned for backward compatibility
  });

  @override
  ConsumerState<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends ConsumerState<GameDetailsScreen> with SingleTickerProviderStateMixin {
  Game? _detailedGame;
  bool _isLoadingDetails = false;
  List<Play> _plays = [];
  bool _isLoadingPlays = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _detailedGame = widget.game;
    _tabController = TabController(length: 2, vsync: this);

    // Fetch details once if we don't have them
    if (_needsDetails(widget.game)) {
      _fetchGameDetails();
    }

    // Load play history for this game
    _loadPlays();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _needsDetails(Game game) {
    // If we don't have description, categories, mechanics, or expansion info, we need details
    return game.description == null ||
           game.categories == null ||
           game.mechanics == null ||
           (game.baseGame == null && game.expansions == null);
  }

  Future<void> _onExpansionTap(int expansionBggId, String expansionName) async {
    // Check if we own this expansion
    final ownedGame = await ref.read(gamesProvider.notifier).getGameByBggId(expansionBggId);

    if (ownedGame != null) {
      // Navigate to the game details screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(game: ownedGame),
          ),
        );
      }
    } else {
      // Show a message that we don't own this game
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Game Not Owned'),
            content: Text('You don\'t own "$expansionName" in your collection yet.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
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

  Future<void> _saveLocation(String? location) async {
    try {
      await ref.read(gamesProvider.notifier).updateGameLocation(
            widget.game.id!,
            location ?? '',
          );

      // Update local state to reflect the change immediately
      setState(() {
        final currentGame = _detailedGame ?? widget.game;
        _detailedGame = currentGame.copyWith(location: location ?? '');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
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

    // Show won dialog
    bool wonValue = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Record Play'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: wonValue,
                    onChanged: (value) {
                      setState(() {
                        wonValue = value ?? false;
                      });
                    },
                    title: const Text('Won'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      final db = ref.read(databaseServiceProvider);
      final play = Play(
        gameId: widget.game.id!,
        datePlayed: selectedDate,
        won: wonValue,
      );

      await db.insertPlay(play);

      // Reload plays
      await _loadPlays();

      // Reload recently played games list
      ref.read(recentlyPlayedGamesProvider.notifier).loadRecentlyPlayedGames();

      if (mounted) {
        final wonText = wonValue ? ' - Won!' : ' - Lost';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Play recorded for ${DateFormat('MMM d, yyyy').format(selectedDate)}$wonText'),
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

  Future<void> _editPlay(Play play) async {
    // Show date picker with initial date
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: play.datePlayed,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    // Show won dialog with initial value
    bool wonValue = play.won ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Play'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: wonValue,
                    onChanged: (value) {
                      setState(() {
                        wonValue = value ?? false;
                      });
                    },
                    title: const Text('Won'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      final db = ref.read(databaseServiceProvider);
      final updatedPlay = play.copyWith(
        datePlayed: selectedDate,
        won: wonValue,
      );

      await db.updatePlay(updatedPlay);

      // Reload plays
      await _loadPlays();

      // Reload recently played games list
      ref.read(recentlyPlayedGamesProvider.notifier).loadRecentlyPlayedGames();

      if (mounted) {
        final wonText = wonValue ? ' - Won!' : ' - Lost';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Play updated for ${DateFormat('MMM d, yyyy').format(selectedDate)}$wonText'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating play: $e'),
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

        // Reload recently played games list
        ref.read(recentlyPlayedGamesProvider.notifier).loadRecentlyPlayedGames();

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

  Widget _buildDetailsTab(Game game) {
    return SingleChildScrollView(
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
          const SizedBox(height: 16),

          // Stats
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

          _InfoRow(
            icon: Icons.location_on,
            label: 'Location',
            value: game.location?.isNotEmpty == true ? game.location! : 'Not set',
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
            _ExpandableDescription(
              description: _stripHtmlTags(game.description!),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // Categories and Mechanics
          if (game.categories != null && game.categories!.isNotEmpty) ...[
            Text(
              'Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              children: game.categories!.asMap().entries.map((entry) {
                final color = _getColorForIndex(entry.key, true);
                return _TagChip(
                  label: entry.value,
                  color: color,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          if (game.mechanics != null && game.mechanics!.isNotEmpty) ...[
            Text(
              'Mechanics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              children: game.mechanics!.asMap().entries.map((entry) {
                final color = _getColorForIndex(entry.key, false);
                return _TagChip(
                  label: entry.value,
                  color: color,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          if ((game.categories != null && game.categories!.isNotEmpty) ||
              (game.mechanics != null && game.mechanics!.isNotEmpty)) ...[
            const Divider(),
            const SizedBox(height: 16),
          ],

          // Expansions or Base Game (only show for owned games)
          if (widget.isOwned && game.baseGame != null) ...[
            // This is an expansion, show the base game
            Text(
              'Base Game',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              children: [
                _ClickableTagChip(
                  label: game.baseGame!.name,
                  color: Colors.blueGrey,
                  onTap: () => _onExpansionTap(game.baseGame!.bggId, game.baseGame!.name),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ] else if (widget.isOwned && game.expansions != null && game.expansions!.isNotEmpty) ...[
            // This is a base game, show expansions
            Text(
              'Expansions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _ExpandableExpansions(
              expansions: game.expansions!,
              onExpansionTap: _onExpansionTap,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // Location Editor (only for owned games)
          if (widget.isOwned) ...[
            Text(
              'Set Location',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            LocationPicker(
              initialLocation: game.location,
              onLocationChanged: _saveLocation,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isOwned) ...[
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
                      leading: play.won == null
                          ? const Icon(Icons.event, color: Colors.blue)
                          : play.won!
                              ? const Icon(Icons.emoji_events, color: Colors.amber)
                              : const Icon(Icons.event, color: Colors.grey),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(play.datePlayed),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (play.won != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: play.won! ? Colors.green[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                play.won! ? 'Won' : 'Lost',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: play.won! ? Colors.green[800] : Colors.red[800],
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        'Recorded ${DateFormat('MMM d, yyyy').format(play.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editPlay(play),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deletePlay(play.id!),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
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
          if (!_isLoadingDetails && widget.isOwned)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _fetchGameDetails,
              tooltip: 'Sync from BGG',
            ),
          if (widget.isOwned)
            IconButton(
              icon: const Icon(Icons.nfc),
              onPressed: _writeToNfc,
              tooltip: 'Write to NFC Tag',
            ),
        ],
      ),
      body: Column(
        children: [
          // Not Owned Banner
          if (!widget.isOwned)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[900]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This game is not in your collection',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Game Image
          if (game.imageUrl != null)
            CachedNetworkImage(
              imageUrl: game.imageUrl!,
              height: 250,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                height: 250,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 250,
                color: Colors.grey[300],
                child: const Icon(Icons.casino, size: 64),
              ),
            )
          else
            Container(
              height: 250,
              color: Colors.grey[300],
              child: const Icon(Icons.casino, size: 64),
            ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Play History'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(game),
                _buildPlayHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&quot;', '"');
  }

  Color _getColorForIndex(int index, bool isCategory) {
    // Different color palettes for categories and mechanics
    final categoryColors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];

    final mechanicColors = [
      Colors.red,
      Colors.amber,
      Colors.deepPurple,
      Colors.deepOrange,
      Colors.lime,
      Colors.brown,
      Colors.blueGrey,
      Colors.lightGreen,
    ];

    final colors = isCategory ? categoryColors : mechanicColors;
    return colors[index % colors.length];
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

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(51), // 0.2 * 255 = 51
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color.darken(0.3),
        ),
      ),
    );
  }
}

class _ClickableTagChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ClickableTagChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(51), // 0.2 * 255 = 51
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1),
        ),
        child: IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color.darken(0.3),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward,
                size: 12,
                color: color.darken(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  final String description;

  const _ExpandableDescription({
    required this.description,
  });

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.description,
          maxLines: _isExpanded ? null : 2,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Text(
            _isExpanded ? 'Show less' : 'Show more',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandableExpansions extends StatefulWidget {
  final List<ExpansionReference> expansions;
  final Function(int, String) onExpansionTap;

  const _ExpandableExpansions({
    required this.expansions,
    required this.onExpansionTap,
  });

  @override
  State<_ExpandableExpansions> createState() => _ExpandableExpansionsState();
}

class _ExpandableExpansionsState extends State<_ExpandableExpansions> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final shouldCollapse = widget.expansions.length > 3;
    final displayedExpansions = shouldCollapse && !_isExpanded
        ? widget.expansions.take(3).toList()
        : widget.expansions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: displayedExpansions.map((expansion) {
            return _ClickableTagChip(
              label: expansion.name,
              color: Colors.blueGrey,
              onTap: () => widget.onExpansionTap(expansion.bggId, expansion.name),
            );
          }).toList(),
        ),
        if (shouldCollapse) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded
                  ? 'Show less'
                  : 'Show ${widget.expansions.length - 3} more...',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

extension ColorExtension on Color {
  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }
}
