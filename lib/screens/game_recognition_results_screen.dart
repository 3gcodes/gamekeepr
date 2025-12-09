import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamekeepr/models/game_match_result.dart';
import 'package:gamekeepr/screens/game_details_screen.dart';
import 'package:gamekeepr/services/nfc_service.dart';
import 'package:gamekeepr/providers/app_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GameRecognitionResultsScreen extends ConsumerStatefulWidget {
  final List<GameMatchResult> matches;
  final List<String> extractedTexts;

  const GameRecognitionResultsScreen({
    super.key,
    required this.matches,
    required this.extractedTexts,
  });

  @override
  ConsumerState<GameRecognitionResultsScreen> createState() =>
      _GameRecognitionResultsScreenState();
}

class _GameRecognitionResultsScreenState
    extends ConsumerState<GameRecognitionResultsScreen> {
  final NfcService _nfcService = NfcService();

  // Track which games have been tagged in this session
  final Map<int, bool> _taggedGames = {};

  // Check if a game has an NFC tag (initial state + session updates)
  bool _hasNfcTag(GameMatchResult match) {
    // First check if we updated it in this session
    if (_taggedGames.containsKey(match.game.bggId)) {
      return _taggedGames[match.game.bggId]!;
    }
    // Otherwise use the initial state from the game object
    return match.game.hasNfcTag;
  }

  Future<void> _writeNfcTag(GameMatchResult match) async {
    // Check if NFC is available
    final isAvailable = await _nfcService.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC is not available on this device'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show scanning dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Hold your iPhone near the NFC tag...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Small delay to ensure dialog is visible
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Use BGG ID for the NFC tag
      final success = await _nfcService.writeGameId(match.game.bggId);

      if (mounted) {
        Navigator.pop(context); // Close dialog

        if (success) {
          // Mark the game as having an NFC tag in the database
          final db = ref.read(databaseServiceProvider);
          await db.updateGameHasNfcTag(match.game.id!, true);

          // Update local state
          setState(() {
            _taggedGames[match.game.bggId] = true;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('NFC tag written for ${match.game.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to write NFC tag'),
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
            content: Text('Error writing NFC tag: $e'),
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
        title: const Text('Recognition Results'),
      ),
      body: widget.matches.isEmpty
          ? _buildNoResultsView()
          : _buildResultsView(context),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No games found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No matching games were found in your collection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tips:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Ensure game titles on spines are clearly visible\n'
              '• Try better lighting\n'
              '• Make sure games are in your collection',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    return Column(
      children: [
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${widget.matches.length} ${widget.matches.length == 1 ? 'game' : 'games'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recognized ${widget.extractedTexts.length} text ${widget.extractedTexts.length == 1 ? 'segment' : 'segments'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: widget.matches.length,
            itemBuilder: (context, index) {
              final match = widget.matches[index];
              return _buildMatchCard(context, match);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(BuildContext context, GameMatchResult match) {
    Color confidenceColor;
    String confidenceLabel;
    IconData confidenceIcon;

    if (match.isStrongMatch) {
      confidenceColor = Colors.green;
      confidenceLabel = 'High confidence';
      confidenceIcon = Icons.check_circle;
    } else if (match.isMediumMatch) {
      confidenceColor = Colors.orange;
      confidenceLabel = 'Medium confidence';
      confidenceIcon = Icons.info;
    } else {
      confidenceColor = Colors.grey;
      confidenceLabel = 'Low confidence';
      confidenceIcon = Icons.help_outline;
    }

    final hasTag = _hasNfcTag(match);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: match.game.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: match.game.thumbnailUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.error),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
            const SizedBox(width: 12),

            // Game info
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameDetailsScreen(
                        game: match.game,
                        isOwned: match.game.owned,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.game.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          confidenceIcon,
                          size: 16,
                          color: confidenceColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          confidenceLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: confidenceColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(match.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Matched: "${match.matchedText}"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match.game.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              match.game.location!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hasTag) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.nfc,
                            size: 14,
                            color: Colors.purple.shade600,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'NFC Tag',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons
            Column(
              children: [
                // View details button
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameDetailsScreen(
                          game: match.game,
                          isOwned: match.game.owned,
                        ),
                      ),
                    );
                  },
                  tooltip: 'View details',
                ),
                // Write NFC tag button (only show if no tag)
                if (!hasTag)
                  IconButton(
                    icon: Icon(
                      Icons.nfc,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () => _writeNfcTag(match),
                    tooltip: 'Write NFC tag',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
