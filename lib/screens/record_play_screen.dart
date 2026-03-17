import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/play.dart';
import '../models/player.dart';
import '../models/play_with_players.dart';
import '../providers/app_providers.dart';

class RecordPlayScreen extends ConsumerStatefulWidget {
  final Game game;
  final PlayWithPlayers? existingPlay;

  const RecordPlayScreen({
    super.key,
    required this.game,
    this.existingPlay,
  });

  @override
  ConsumerState<RecordPlayScreen> createState() => _RecordPlayScreenState();
}

class _RecordPlayScreenState extends ConsumerState<RecordPlayScreen> {
  late DateTime _selectedDate;
  final _locationController = TextEditingController();
  List<_SelectedPlayer> _selectedPlayers = [];
  List<String> _locationSuggestions = [];
  bool _isSaving = false;

  bool get _isEditing => widget.existingPlay != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final existing = widget.existingPlay!;
      _selectedDate = existing.play.datePlayed;
      _locationController.text = existing.play.location ?? '';
      _selectedPlayers = existing.players.map((pws) {
        return _SelectedPlayer(player: pws.player, winner: pws.winner, score: pws.score);
      }).toList();
    } else {
      _selectedDate = DateTime.now();
    }
    _loadLocationSuggestions();
  }

  @override
  void dispose() {
    _locationController.dispose();
    for (final sp in _selectedPlayers) {
      sp.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLocationSuggestions() async {
    final db = ref.read(databaseServiceProvider);
    final locations = await db.getAllPlayLocations();
    if (mounted) {
      setState(() {
        _locationSuggestions = locations;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _toggleWinner(int index) {
    setState(() {
      _selectedPlayers[index].winner = !_selectedPlayers[index].winner;
    });
  }

  void _removePlayer(int index) {
    _selectedPlayers[index].dispose();
    setState(() {
      _selectedPlayers.removeAt(index);
    });
  }

  Future<void> _showAddPlayersSheet() async {
    // Ensure players are loaded
    final playersAsync = ref.read(playersProvider);
    List<Player> allPlayers = [];
    playersAsync.whenData((players) => allPlayers = players);

    if (allPlayers.isEmpty) {
      // Force load if not yet loaded
      await ref.read(playersProvider.notifier).loadPlayers();
      final updated = ref.read(playersProvider);
      updated.whenData((players) => allPlayers = players);
    }

    final selectedIds = _selectedPlayers.map((sp) => sp.player.id).toSet();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _AddPlayersSheet(
          allPlayers: allPlayers,
          selectedPlayerIds: selectedIds,
          onPlayersSelected: (players) {
            setState(() {
              // Add newly selected players (keeping existing winner status)
              for (final player in players) {
                final existing = _selectedPlayers.indexWhere(
                  (sp) => sp.player.id == player.id,
                );
                if (existing == -1) {
                  _selectedPlayers.add(_SelectedPlayer(player: player));
                }
              }
              // Remove deselected players
              final toRemove = _selectedPlayers
                  .where((sp) => !players.any((p) => p.id == sp.player.id))
                  .toList();
              for (final sp in toRemove) {
                sp.dispose();
              }
              _selectedPlayers.removeWhere(
                (sp) => !players.any((p) => p.id == sp.player.id),
              );
            });
          },
          onPlayerCreated: (player) {
            setState(() {
              _selectedPlayers.add(_SelectedPlayer(player: player));
            });
          },
          ref: ref,
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final location = _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim();

      if (_isEditing) {
        // Update existing play
        final updatedPlay = widget.existingPlay!.play.copyWith(
          datePlayed: _selectedDate,
          location: location,
        );
        await db.updatePlay(updatedPlay);

        // Update play-player associations
        if (updatedPlay.id != null) {
          final playerIds = _selectedPlayers
              .where((sp) => sp.player.id != null)
              .map((sp) => sp.player.id!)
              .toList();
          final winnerIds = _selectedPlayers
              .where((sp) => sp.winner && sp.player.id != null)
              .map((sp) => sp.player.id!)
              .toList();
          final playerScores = <int, String>{};
          for (final sp in _selectedPlayers) {
            final scoreText = sp.scoreController.text.trim();
            if (sp.player.id != null && scoreText.isNotEmpty) {
              playerScores[sp.player.id!] = scoreText;
            }
          }
          await db.setPlayPlayers(updatedPlay.id!, playerIds, winnerIds, playerScores: playerScores);
        }

        // Sync edit to BGG if we have a BGG play ID
        if (updatedPlay.bggPlayId != null) {
          await _syncEditToBgg(updatedPlay.bggPlayId!, location);
        }
      } else {
        // Create new play
        final play = Play(
          gameId: widget.game.id!,
          datePlayed: _selectedDate,
          location: location,
        );
        final savedPlay = await db.insertPlay(play);

        // Set play-player associations
        if (savedPlay.id != null && _selectedPlayers.isNotEmpty) {
          final playerIds = _selectedPlayers
              .where((sp) => sp.player.id != null)
              .map((sp) => sp.player.id!)
              .toList();
          final winnerIds = _selectedPlayers
              .where((sp) => sp.winner && sp.player.id != null)
              .map((sp) => sp.player.id!)
              .toList();
          final playerScores = <int, String>{};
          for (final sp in _selectedPlayers) {
            final scoreText = sp.scoreController.text.trim();
            if (sp.player.id != null && scoreText.isNotEmpty) {
              playerScores[sp.player.id!] = scoreText;
            }
          }
          await db.setPlayPlayers(savedPlay.id!, playerIds, winnerIds, playerScores: playerScores);
        }

        // Sync play to BGG (best-effort, don't fail local save)
        await _syncPlayToBgg(savedPlay.id!, location);
      }

      // Reload recently played games list
      ref.read(recentlyPlayedGamesProvider.notifier).loadRecentlyPlayedGames();
      // Refresh location suggestions cache
      ref.invalidate(playLocationsProvider);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving play: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _syncEditToBgg(int bggPlayId, String? location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('bgg_username') ?? '';
      const secureStorage = FlutterSecureStorage();
      final password = await secureStorage.read(key: 'bgg_password') ?? '';

      if (username.isEmpty || password.isEmpty) return;

      final bggService = ref.read(bggServiceProvider);

      if (!bggService.isLoggedIn) {
        await bggService.login(username, password);
      }

      final bggPlayers = _selectedPlayers.map((sp) {
        return <String, dynamic>{
          'name': sp.player.name,
          'username': sp.player.bggUsername ?? '',
          'win': sp.winner,
          'score': sp.scoreController.text.trim(),
        };
      }).toList();

      await bggService.updatePlay(
        bggPlayId: bggPlayId,
        bggId: widget.game.bggId,
        playdate: _selectedDate,
        location: location,
        players: bggPlayers,
      );
    } catch (e) {
      print('⚠️ Failed to sync edit to BGG: $e');
    }
  }

  Future<void> _syncPlayToBgg(int localPlayId, String? location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('bgg_username') ?? '';
      const secureStorage = FlutterSecureStorage();
      final password = await secureStorage.read(key: 'bgg_password') ?? '';

      if (username.isEmpty || password.isEmpty) {
        print('⚠️ BGG credentials not set, skipping BGG play sync');
        return;
      }

      final bggService = ref.read(bggServiceProvider);

      // Login if not already logged in
      if (!bggService.isLoggedIn) {
        await bggService.login(username, password);
      }

      // Build player list for BGG
      final bggPlayers = _selectedPlayers.map((sp) {
        return <String, dynamic>{
          'name': sp.player.name,
          'username': sp.player.bggUsername ?? '',
          'userid': 0,
          'win': sp.winner,
          'score': sp.scoreController.text.trim(),
        };
      }).toList();

      final bggPlayId = await bggService.logPlay(
        bggId: widget.game.bggId,
        playdate: _selectedDate,
        location: location,
        players: bggPlayers,
      );

      // Store BGG play ID locally if we got one back
      if (bggPlayId != null) {
        final db = ref.read(databaseServiceProvider);
        await db.updatePlayBggId(localPlayId, bggPlayId);
      }
    } catch (e) {
      // Don't fail the local save if BGG sync fails
      print('⚠️ Failed to sync play to BGG: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Play' : 'Record Play'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game name
            Text(
              widget.game.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Date picker
            Text(
              'Date',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Location field
            Text(
              'Location',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _locationController.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _locationSuggestions;
                }
                return _locationSuggestions.where((location) => location
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (selection) {
                _locationController.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync the controller text on first build
                if (controller.text.isEmpty && _locationController.text.isNotEmpty) {
                  controller.text = _locationController.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: "e.g., John's house",
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    _locationController.text = value;
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Players section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Players',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: _showAddPlayersSheet,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Players'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_selectedPlayers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text(
                  'No players added. Tap "Add Players" to select or create players.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...List.generate(_selectedPlayers.length, (index) {
                final sp = _selectedPlayers[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Winner toggle
                      IconButton(
                        icon: Icon(
                          Icons.emoji_events,
                          color: sp.winner ? Colors.amber : Colors.grey[400],
                          size: 22,
                        ),
                        onPressed: () => _toggleWinner(index),
                        tooltip: sp.winner
                            ? 'Tap to unmark as winner'
                            : 'Tap to mark as winner',
                        visualDensity: VisualDensity.compact,
                      ),
                      // Player name
                      Expanded(
                        flex: 3,
                        child: Text(
                          sp.player.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: sp.winner ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Score field
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: sp.scoreController,
                          decoration: InputDecoration(
                            hintText: 'Score',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType: TextInputType.text,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      // Delete button
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                        onPressed: () => _removePlayer(index),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 32),

            // Save / Cancel buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Update' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Internal mutable holder for selected player + winner + score state
class _SelectedPlayer {
  final Player player;
  bool winner;
  String? score;
  final TextEditingController scoreController;

  _SelectedPlayer({required this.player, this.winner = false, this.score})
      : scoreController = TextEditingController(text: score ?? '');

  void dispose() {
    scoreController.dispose();
  }
}

// Bottom sheet for adding players
class _AddPlayersSheet extends StatefulWidget {
  final List<Player> allPlayers;
  final Set<int?> selectedPlayerIds;
  final ValueChanged<List<Player>> onPlayersSelected;
  final ValueChanged<Player> onPlayerCreated;
  final WidgetRef ref;

  const _AddPlayersSheet({
    required this.allPlayers,
    required this.selectedPlayerIds,
    required this.onPlayersSelected,
    required this.onPlayerCreated,
    required this.ref,
  });

  @override
  State<_AddPlayersSheet> createState() => _AddPlayersSheetState();
}

class _AddPlayersSheetState extends State<_AddPlayersSheet> {
  late Set<int?> _checkedIds;
  late List<Player> _players;
  bool _isCreating = false;
  final _nameController = TextEditingController();
  final _bggUsernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkedIds = Set.from(widget.selectedPlayerIds);
    _players = List.from(widget.allPlayers);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bggUsernameController.dispose();
    super.dispose();
  }

  Future<void> _createPlayer() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final bggUsername = _bggUsernameController.text.trim().isEmpty
        ? null
        : _bggUsernameController.text.trim();

    final player = await widget.ref.read(playersProvider.notifier).addPlayer(
      name: name,
      bggUsername: bggUsername,
    );

    setState(() {
      _players.add(player);
      _checkedIds.add(player.id);
      _isCreating = false;
      _nameController.clear();
      _bggUsernameController.clear();
    });

    // Also notify parent immediately about the new player
    widget.onPlayerCreated(player);
  }

  void _done() {
    final selectedPlayers = _players
        .where((p) => _checkedIds.contains(p.id))
        .toList();
    widget.onPlayersSelected(selectedPlayers);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Players',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton(
                      onPressed: _done,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Player list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ..._players.map((player) {
                      return CheckboxListTile(
                        value: _checkedIds.contains(player.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _checkedIds.add(player.id);
                            } else {
                              _checkedIds.remove(player.id);
                            }
                          });
                        },
                        title: Text(player.name),
                        subtitle: player.bggUsername != null
                            ? Text('BGG: ${player.bggUsername}')
                            : null,
                      );
                    }),

                    const Divider(),

                    // Create new player section
                    if (!_isCreating)
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Create New Player'),
                        onTap: () {
                          setState(() {
                            _isCreating = true;
                          });
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Player',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Name *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _bggUsernameController,
                              decoration: InputDecoration(
                                labelText: 'BGG Username (optional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isCreating = false;
                                      _nameController.clear();
                                      _bggUsernameController.clear();
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _createPlayer,
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
