import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class ManageTagsScreen extends ConsumerStatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  ConsumerState<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends ConsumerState<ManageTagsScreen> {
  List<String> _tags = [];
  Map<String, int> _tagCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final tags = await db.getAllUniqueTags();

      // Get usage count for each tag
      final counts = <String, int>{};
      for (final tag in tags) {
        counts[tag] = await db.getTagUsageCount(tag);
      }

      if (mounted) {
        setState(() {
          _tags = tags;
          _tagCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _renameTag(String oldTag) async {
    final controller = TextEditingController(text: oldTag);

    final newTag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New tag name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim().toLowerCase();
              if (text.isNotEmpty && text != oldTag) {
                Navigator.pop(context, text);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newTag != null && newTag != oldTag) {
      try {
        final db = ref.read(databaseServiceProvider);
        await db.renameTag(oldTag, newTag);

        // Invalidate the tags map provider to refresh search
        ref.invalidate(gameTagsMapProvider);

        await _loadTags();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Renamed "$oldTag" to "$newTag"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error renaming tag: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTag(String tag) async {
    final count = _tagCounts[tag] ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text(
          count > 0
              ? 'Are you sure you want to delete "$tag"?\n\nApplied to $count ${count == 1 ? 'game' : 'games'}.'
              : 'Are you sure you want to delete "$tag"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = ref.read(databaseServiceProvider);
        await db.deleteTagFromAllGames(tag);

        // Invalidate the tags map provider to refresh search
        ref.invalidate(gameTagsMapProvider);

        await _loadTags();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted tag "$tag"'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting tag: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getColorForTag(String tag) {
    // Same color function as in GameTagsWidget
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tags'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tags yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add tags to your games to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    final count = _tagCounts[tag] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getColorForTag(tag),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.label),
                        ),
                        title: Text(
                          tag,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '$count ${count == 1 ? 'game' : 'games'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Rename',
                              onPressed: () => _renameTag(tag),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              color: Colors.red,
                              tooltip: 'Delete',
                              onPressed: () => _deleteTag(tag),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
