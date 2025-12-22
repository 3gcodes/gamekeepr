import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collectible.dart';
import '../models/game.dart';
import '../providers/collectibles_provider.dart';
import '../providers/games_provider.dart';

class AddCollectibleScreen extends ConsumerStatefulWidget {
  final Collectible? collectible; // If provided, we're editing
  final int? preselectedGameId; // If provided, pre-select this game

  const AddCollectibleScreen({
    super.key,
    this.collectible,
    this.preselectedGameId,
  });

  @override
  ConsumerState<AddCollectibleScreen> createState() => _AddCollectibleScreenState();
}

class _AddCollectibleScreenState extends ConsumerState<AddCollectibleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();

  CollectibleType _selectedType = CollectibleType.MINIATURE;
  int? _selectedGameId;
  bool _painted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.collectible != null) {
      // Editing mode
      final c = widget.collectible!;
      _nameController.text = c.name;
      _manufacturerController.text = c.manufacturer ?? '';
      _descriptionController.text = c.description ?? '';
      _quantityController.text = c.quantity.toString();
      _selectedType = c.type;
      _selectedGameId = c.gameId;
      _painted = c.painted;
    } else {
      // Adding mode
      _quantityController.text = '1';
      if (widget.preselectedGameId != null) {
        _selectedGameId = widget.preselectedGameId;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _manufacturerController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final collectible = Collectible(
        id: widget.collectible?.id,
        type: _selectedType,
        name: _nameController.text.trim(),
        manufacturer: _manufacturerController.text.trim().isEmpty ? null : _manufacturerController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 1,
        painted: _painted,
        gameId: _selectedGameId,
        location: widget.collectible?.location,
        hasNfcTag: widget.collectible?.hasNfcTag ?? false,
        imageUrl: widget.collectible?.imageUrl,
        createdAt: widget.collectible?.createdAt,
      );

      if (widget.collectible == null) {
        // Adding new collectible
        await ref.read(collectiblesProvider.notifier).addCollectible(collectible);
      } else {
        // Updating existing collectible
        await ref.read(collectiblesProvider.notifier).updateCollectible(collectible);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.collectible == null
                ? 'Collectible added successfully'
                : 'Collectible updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collectible == null ? 'Add Collectible' : 'Edit Collectible'),
        actions: [
          if (_isLoading)
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
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type Selector
            DropdownButtonFormField<CollectibleType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type *',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: CollectibleType.MINIATURE,
                  child: Text(CollectibleType.MINIATURE.displayName),
                ),
                // Future types can be added here
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Manufacturer
            TextFormField(
              controller: _manufacturerController,
              decoration: const InputDecoration(
                labelText: 'Manufacturer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Quantity
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Quantity is required';
                }
                final qty = int.tryParse(value);
                if (qty == null || qty < 1) {
                  return 'Quantity must be at least 1';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Painted (for miniatures only)
            if (_selectedType == CollectibleType.MINIATURE)
              SwitchListTile(
                value: _painted,
                onChanged: (value) {
                  setState(() {
                    _painted = value;
                  });
                },
                title: const Text('Painted'),
                contentPadding: EdgeInsets.zero,
              ),

            const SizedBox(height: 16),

            // Associated Game
            gamesAsync.when(
              data: (games) {
                final ownedGames = games.where((g) => g.owned).toList();
                return DropdownButtonFormField<int?>(
                  value: _selectedGameId,
                  decoration: const InputDecoration(
                    labelText: 'Associated Game (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...ownedGames.map((game) {
                      return DropdownMenuItem<int?>(
                        value: game.id,
                        child: Text(game.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGameId = value;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error loading games: $error'),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(widget.collectible == null ? 'Add Collectible' : 'Update Collectible'),
            ),
          ],
        ),
      ),
    );
  }
}
