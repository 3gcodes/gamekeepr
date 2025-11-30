import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import '../providers/app_providers.dart';

class GameTagsWidget extends ConsumerStatefulWidget {
  final Game game;

  const GameTagsWidget({
    super.key,
    required this.game,
  });

  @override
  ConsumerState<GameTagsWidget> createState() => _GameTagsWidgetState();
}

class _GameTagsWidgetState extends ConsumerState<GameTagsWidget> {
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _currentTags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    if (widget.game.id == null) return;

    try {
      final db = ref.read(databaseServiceProvider);
      final tags = await db.getTagsForGame(widget.game.id!);
      if (mounted) {
        setState(() {
          _currentTags = tags;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addTags(String input) async {
    if (widget.game.id == null || input.trim().isEmpty) return;

    // Split by comma only and force lowercase
    final newTags = input
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty && !_currentTags.contains(tag))
        .toList();

    if (newTags.isEmpty) return;

    try {
      final db = ref.read(databaseServiceProvider);
      await db.addTagsToGame(widget.game.id!, newTags);

      // Reload tags
      await _loadTags();

      // Invalidate the tags map provider to refresh search
      ref.invalidate(gameTagsMapProvider);

      // Clear input and dismiss keyboard
      _tagController.clear();
      _focusNode.unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${newTags.length} tag(s)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding tags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeTag(String tag) async {
    if (widget.game.id == null) return;

    try {
      final db = ref.read(databaseServiceProvider);
      await db.removeTagFromGame(widget.game.id!, tag);

      // Reload tags
      await _loadTags();

      // Invalidate the tags map provider to refresh search
      ref.invalidate(gameTagsMapProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed tag: $tag'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getColorForTag(String tag) {
    // Generate a consistent color based on tag hash
    final hash = tag.hashCode;
    final colors = [
      Colors.red.shade100,
      Colors.pink.shade100,
      Colors.purple.shade100,
      Colors.deepPurple.shade100,
      Colors.indigo.shade100,
      Colors.blue.shade100,
      Colors.lightBlue.shade100,
      Colors.cyan.shade100,
      Colors.teal.shade100,
      Colors.green.shade100,
      Colors.lightGreen.shade100,
      Colors.lime.shade100,
      Colors.yellow.shade100,
      Colors.amber.shade100,
      Colors.orange.shade100,
      Colors.deepOrange.shade100,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add tags section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('tag_input_field'),
                controller: _tagController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'Add tags',
                  hintText: 'Type tags separated by commas',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addTags(_tagController.text),
                  ),
                ),
                onSubmitted: _addTags,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: You can add multiple tags at once by separating them with commas',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Current tags
        if (_currentTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: _getColorForTag(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            ),
          ),

        if (_currentTags.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No tags yet. Add some above!',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }
}
