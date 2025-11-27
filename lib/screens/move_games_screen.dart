import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import '../providers/app_providers.dart';
import '../widgets/location_picker.dart';

class MoveGamesScreen extends ConsumerStatefulWidget {
  const MoveGamesScreen({super.key});

  @override
  ConsumerState<MoveGamesScreen> createState() => _MoveGamesScreenState();
}

class _MoveGamesScreenState extends ConsumerState<MoveGamesScreen> {
  final List<Game> _gamesToMove = [];
  String? _targetLocation;
  bool _isScanning = false;

  Future<void> _scanGame() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final nfcService = ref.read(nfcServiceProvider);
      final tagData = await nfcService.readTag();

      if (tagData == null || tagData['type'] != 'game') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid or empty tag'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isScanning = false;
        });
        return;
      }

      // Lookup game by BGG ID
      final gameId = tagData['data'] as int;
      final game = await ref.read(gamesProvider.notifier).getGameByBggId(gameId);

      if (mounted) {
        if (game != null) {
          // Check if game is already in the list
          if (_gamesToMove.any((g) => g.id == game.id)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${game.name} is already in the list'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            setState(() {
              _gamesToMove.add(game);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${game.name}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game with ID $gameId not found in collection'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isScanning = false;
    });
  }

  void _removeGame(Game game) {
    setState(() {
      _gamesToMove.removeWhere((g) => g.id == game.id);
    });
  }

  Future<void> _saveChanges() async {
    if (_gamesToMove.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No games to move'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final db = ref.read(databaseServiceProvider);

      // Update location for all games in the list
      for (final game in _gamesToMove) {
        if (game.id != null) {
          await db.updateGameLocation(game.id!, _targetLocation ?? '');
        }
      }

      // Reload games provider
      ref.read(gamesProvider.notifier).loadGames();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved ${_gamesToMove.length} game(s) to ${_targetLocation ?? "no location"}'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
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
        title: const Text('Move Game(s)'),
        actions: [
          if (_gamesToMove.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: Column(
        children: [
          // Scan button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanGame,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.nfc),
                label: Text(_isScanning ? 'Scanning...' : 'Scan Game'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // Location picker
          if (_gamesToMove.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LocationPicker(
                initialLocation: _targetLocation,
                onLocationChanged: (location) {
                  setState(() {
                    _targetLocation = location;
                  });
                },
              ),
            ),

          if (_gamesToMove.isNotEmpty) const SizedBox(height: 16),

          // Games list
          Expanded(
            child: _gamesToMove.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.nfc,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No games scanned yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan game NFC tags to add them to the batch',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _gamesToMove.length,
                    itemBuilder: (context, index) {
                      final game = _gamesToMove[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(game.name),
                          subtitle: game.location?.isNotEmpty == true
                              ? Text('Current: ${game.location}')
                              : const Text('Current: Not set'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                            onPressed: () => _removeGame(game),
                            tooltip: 'Remove',
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Save button at bottom
          if (_gamesToMove.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: Text('Move ${_gamesToMove.length} Game(s)'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
