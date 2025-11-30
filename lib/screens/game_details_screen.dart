import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import '../models/play.dart';
import '../models/scheduled_game.dart';
import '../models/game_loan.dart';
import '../providers/app_providers.dart';
import '../widgets/location_picker.dart';
import '../widgets/loan_game_dialog.dart';
import '../widgets/game_tags_widget.dart';
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
  List<ScheduledGame> _scheduledGames = [];
  bool _isLoadingScheduled = false;
  List<GameLoan> _loans = [];
  bool _isLoadingLoans = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _detailedGame = widget.game;
    _tabController = TabController(
      length: 5,
      vsync: this,
    );

    // Fetch details once if we don't have them
    if (_needsDetails(widget.game)) {
      _fetchGameDetails();
    }

    // Load play history for this game
    _loadPlays();

    // Load scheduled games for this game
    _loadScheduledGames();

    // Load loan history for this game
    _loadLoans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _needsDetails(Game game) {
    // If we don't have description, categories, mechanics, or expansion info, we need details
    if (game.description == null ||
        game.categories == null ||
        game.mechanics == null ||
        (game.baseGame == null && game.expansions == null)) {
      return true;
    }

    // Auto-sync if never synced or synced more than 7 days ago
    if (game.lastSynced == null) {
      return true;
    }

    final daysSinceSync = DateTime.now().difference(game.lastSynced!).inDays;
    return daysSinceSync >= 7;
  }

  Future<void> _toggleWishlist() async {
    final game = _detailedGame;
    if (game == null || game.id == null) return;

    final newWishlistStatus = !game.wishlisted;

    try {
      final updatedGame = await ref.read(gamesProvider.notifier).toggleWishlist(
        game.id!,
        newWishlistStatus,
      );

      if (updatedGame != null && mounted) {
        setState(() {
          _detailedGame = updatedGame;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newWishlistStatus
                  ? 'Added to wishlist'
                  : 'Removed from wishlist',
            ),
            backgroundColor: newWishlistStatus ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating wishlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleOwned() async {
    final game = _detailedGame;
    if (game == null || game.id == null) return;

    final newOwnedStatus = !game.owned;

    try {
      final updatedGame = await ref.read(gamesProvider.notifier).toggleOwned(
        game.id!,
        newOwnedStatus,
      );

      if (updatedGame != null && mounted) {
        setState(() {
          _detailedGame = updatedGame;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newOwnedStatus
                  ? 'Marked as owned'
                  : 'Marked as not owned',
            ),
            backgroundColor: newOwnedStatus ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating owned status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadScheduledGames() async {
    final game = _detailedGame;
    if (game == null || game.id == null) return;

    setState(() {
      _isLoadingScheduled = true;
    });

    try {
      final scheduledGames = await ref
          .read(scheduledGamesProvider.notifier)
          .getScheduledGamesForGame(game.id!);

      if (mounted) {
        setState(() {
          _scheduledGames = scheduledGames;
          _isLoadingScheduled = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingScheduled = false;
        });
      }
    }
  }

  Future<void> _loadLoans() async {
    final game = _detailedGame;
    if (game == null || game.id == null) return;

    setState(() {
      _isLoadingLoans = true;
    });

    try {
      final loans = await ref
          .read(loansProvider.notifier)
          .getLoansForGame(game.id!);

      if (mounted) {
        setState(() {
          _loans = loans;
          _isLoadingLoans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLoans = false;
        });
      }
    }
  }

  Future<void> _showScheduleDialog() async {
    final game = _detailedGame;
    if (game == null || game.id == null) return;

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 19, minute: 0);
    final locationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Game Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
                // Time picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time'),
                  subtitle: Text(selectedTime.format(context)),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = time;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                // Location field
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'e.g., John\'s house, Game store',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final scheduledDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      try {
        await ref.read(scheduledGamesProvider.notifier).scheduleGame(
          gameId: game.id!,
          scheduledDateTime: scheduledDateTime,
          location: locationController.text.isEmpty ? null : locationController.text,
        );

        await _loadScheduledGames();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game session scheduled!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error scheduling game: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    locationController.dispose();
  }

  Future<void> _deleteScheduledGame(ScheduledGame scheduledGame) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scheduled Session'),
        content: const Text('Are you sure you want to delete this scheduled session?'),
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

    if (confirmed == true && scheduledGame.id != null) {
      try {
        await ref.read(scheduledGamesProvider.notifier).deleteScheduledGame(scheduledGame.id!);
        await _loadScheduledGames();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scheduled session deleted'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting session: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editScheduledGame(ScheduledGame scheduledGame) async {
    final game = _detailedGame;
    if (game == null || game.id == null || scheduledGame.id == null) return;

    DateTime selectedDate = scheduledGame.scheduledDateTime;
    TimeOfDay selectedTime = TimeOfDay(
      hour: scheduledGame.scheduledDateTime.hour,
      minute: scheduledGame.scheduledDateTime.minute,
    );
    final locationController = TextEditingController(text: scheduledGame.location ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Game Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
                // Time picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time'),
                  subtitle: Text(selectedTime.format(context)),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = time;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                // Location field
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'e.g., John\'s house, Game store',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final scheduledDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      try {
        final updatedScheduledGame = scheduledGame.copyWith(
          scheduledDateTime: scheduledDateTime,
          location: locationController.text.isEmpty ? null : locationController.text,
        );

        await ref.read(scheduledGamesProvider.notifier).updateScheduledGame(updatedScheduledGame);
        await _loadScheduledGames();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game session updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating session: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    locationController.dispose();
  }

  Future<void> _shareGame() async {
    final game = _detailedGame;
    if (game == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Download game image if available
      ui.Image? gameImage;
      if (game.imageUrl != null) {
        try {
          final response = await http.get(Uri.parse(game.imageUrl!));
          if (response.statusCode == 200) {
            final codec = await ui.instantiateImageCodec(response.bodyBytes);
            final frame = await codec.getNextFrame();
            gameImage = frame.image;
          }
        } catch (e) {
          // Ignore image download errors, continue without image
        }
      }

      // Create the share card image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const cardWidth = 400.0;
      const cardHeight = 500.0;
      const padding = 24.0;

      // Draw background with green gradient
      final backgroundPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, cardHeight),
          [const Color(0xFF1B5E20), const Color(0xFF43A047)],
        );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
          const Radius.circular(20),
        ),
        backgroundPaint,
      );

      // Draw game image if available
      double contentStartY = padding;
      if (gameImage != null) {
        const imageSize = 120.0;
        final srcRect = Rect.fromLTWH(
          0, 0,
          gameImage.width.toDouble(),
          gameImage.height.toDouble(),
        );
        final dstRect = Rect.fromLTWH(
          (cardWidth - imageSize) / 2,
          contentStartY,
          imageSize,
          imageSize,
        );

        // Draw circular clip for image
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(dstRect, const Radius.circular(12)));
        canvas.drawImageRect(gameImage, srcRect, dstRect, Paint());
        canvas.restore();

        contentStartY += imageSize + 20;
      }

      // Draw "Check out this game!" header
      final headerParagraph = _buildParagraph(
        'Check out this game!',
        26,
        FontWeight.bold,
        Colors.white,
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        headerParagraph,
        Offset(padding, contentStartY),
      );
      contentStartY += headerParagraph.height + 16;

      // Draw game name
      final nameParagraph = _buildParagraph(
        game.name,
        22,
        FontWeight.w600,
        Colors.white,
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        nameParagraph,
        Offset(padding, contentStartY),
      );
      contentStartY += nameParagraph.height + 24;

      // Draw divider
      final dividerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(padding * 2, contentStartY),
        Offset(cardWidth - (padding * 2), contentStartY),
        dividerPaint,
      );
      contentStartY += 24;

      // Draw game info
      final infoParagraph = _buildParagraph(
        '${game.playersInfo} • ${game.playtimeInfo}',
        16,
        FontWeight.w500,
        Colors.white.withValues(alpha: 0.9),
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        infoParagraph,
        Offset(padding, contentStartY),
      );
      contentStartY += infoParagraph.height + 16;

      // Draw rating if available
      if (game.averageRating != null) {
        final ratingParagraph = _buildParagraph(
          '⭐ ${game.averageRating!.toStringAsFixed(1)} Rating',
          18,
          FontWeight.bold,
          Colors.amber,
          cardWidth - (padding * 2),
          TextAlign.center,
        );
        canvas.drawParagraph(
          ratingParagraph,
          Offset(padding, contentStartY),
        );
        contentStartY += ratingParagraph.height + 16;
      }

      // Draw BGG link
      final bggUrl = 'boardgamegeek.com/boardgame/${game.bggId}';
      final bggParagraph = _buildParagraph(
        bggUrl,
        14,
        FontWeight.w500,
        Colors.white.withValues(alpha: 0.8),
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        bggParagraph,
        Offset(padding, contentStartY),
      );

      // Draw app branding at bottom
      final brandingParagraph = _buildParagraph(
        'Shared from Game Keepr',
        12,
        FontWeight.normal,
        Colors.white.withValues(alpha: 0.6),
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        brandingParagraph,
        Offset(padding, cardHeight - padding - brandingParagraph.height),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(cardWidth.toInt(), cardHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw Exception('Failed to create image');

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/game_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Share the image with BGG link
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Check out ${game.name}!\n\nhttps://boardgamegeek.com/boardgame/${game.bggId}',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 100, 100),
        );
      }

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareScheduledGame(ScheduledGame scheduledGame) async {
    final game = _detailedGame;
    if (game == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Download game image if available
      ui.Image? gameImage;
      if (game.imageUrl != null) {
        try {
          final response = await http.get(Uri.parse(game.imageUrl!));
          if (response.statusCode == 200) {
            final codec = await ui.instantiateImageCodec(response.bodyBytes);
            final frame = await codec.getNextFrame();
            gameImage = frame.image;
          }
        } catch (e) {
          // Ignore image download errors, continue without image
        }
      }

      // Create the share card image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const cardWidth = 400.0;
      const cardHeight = 500.0;
      const padding = 24.0;

      // Draw background
      final backgroundPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, cardHeight),
          [const Color(0xFF1a237e), const Color(0xFF3949ab)],
        );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
          const Radius.circular(20),
        ),
        backgroundPaint,
      );

      // Draw game image if available
      double contentStartY = padding;
      if (gameImage != null) {
        const imageSize = 120.0;
        final srcRect = Rect.fromLTWH(
          0, 0,
          gameImage.width.toDouble(),
          gameImage.height.toDouble(),
        );
        final dstRect = Rect.fromLTWH(
          (cardWidth - imageSize) / 2,
          contentStartY,
          imageSize,
          imageSize,
        );

        // Draw circular clip for image
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(dstRect, const Radius.circular(12)));
        canvas.drawImageRect(gameImage, srcRect, dstRect, Paint());
        canvas.restore();

        contentStartY += imageSize + 20;
      }

      // Draw "Game Night!" header
      final headerParagraph = _buildParagraph(
        'Game Night!',
        28,
        FontWeight.bold,
        Colors.white,
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        headerParagraph,
        Offset(padding, contentStartY),
      );
      contentStartY += headerParagraph.height + 16;

      // Draw game name
      final nameParagraph = _buildParagraph(
        game.name,
        22,
        FontWeight.w600,
        Colors.white,
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        nameParagraph,
        Offset(padding, contentStartY),
      );
      contentStartY += nameParagraph.height + 24;

      // Draw divider
      final dividerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(padding * 2, contentStartY),
        Offset(cardWidth - (padding * 2), contentStartY),
        dividerPaint,
      );
      contentStartY += 24;

      // Draw date
      final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(scheduledGame.scheduledDateTime);
      final dateParagraph = _buildParagraph(
        dateStr,
        18,
        FontWeight.w500,
        Colors.white,
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        dateParagraph,
        Offset(padding, contentStartY),
      );
      contentStartY += dateParagraph.height + 8;

      // Draw time
      final timeStr = DateFormat('h:mm a').format(scheduledGame.scheduledDateTime);
      final timeParagraph = _buildParagraph(
        timeStr,
        24,
        FontWeight.bold,
        Colors.amber,
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        timeParagraph,
        Offset(padding, contentStartY),
      );
      contentStartY += timeParagraph.height + 16;

      // Draw location if available
      if (scheduledGame.location != null && scheduledGame.location!.isNotEmpty) {
        final locationParagraph = _buildParagraph(
          '📍 ${scheduledGame.location}',
          16,
          FontWeight.normal,
          Colors.white.withValues(alpha: 0.9),
          cardWidth - (padding * 2),
          TextAlign.center,
        );
        canvas.drawParagraph(
          locationParagraph,
          Offset(padding, contentStartY),
        );
        contentStartY += locationParagraph.height + 16;
      }

      // Draw app branding at bottom
      final brandingParagraph = _buildParagraph(
        'Shared from Game Keepr',
        12,
        FontWeight.normal,
        Colors.white.withValues(alpha: 0.6),
        cardWidth - (padding * 2),
        TextAlign.center,
      );
      canvas.drawParagraph(
        brandingParagraph,
        Offset(padding, cardHeight - padding - brandingParagraph.height),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(cardWidth.toInt(), cardHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw Exception('Failed to create image');

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/game_session_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Share the image
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Join me for ${game.name} on $dateStr at $timeStr!',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 100, 100),
        );
      }

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  ui.Paragraph _buildParagraph(
    String text,
    double fontSize,
    FontWeight fontWeight,
    Color color,
    double width,
    TextAlign textAlign,
  ) {
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: textAlign,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight))
      ..addText(text);
    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    return paragraph;
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
      // Ensure token is loaded before using the service
      final bggService = ref.read(bggServiceProvider);
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final token = prefs.getString('bgg_api_token') ?? '';
      if (token.isNotEmpty) {
        bggService.setBearerToken(token);
      }

      final detailedGame = await bggService.fetchGameDetails(widget.game.bggId);

      // Preserve the database ID, location, and ownership status
      final updatedGame = detailedGame.copyWith(
        id: widget.game.id,
        location: widget.game.location,
        owned: widget.game.owned,
        wishlisted: widget.game.wishlisted,
        hasNfcTag: widget.game.hasNfcTag,
      );

      // Update database
      final db = ref.read(databaseServiceProvider);
      await db.updateGame(updatedGame);

      // Sync plays from BGG if we have a username
      if (widget.game.id != null) {
        final username = prefs.getString('bgg_username') ?? '';
        if (username.isNotEmpty) {
          try {
            print('🎲 Syncing plays from BGG...');
            final bggPlays = await bggService.fetchPlaysForGame(username, widget.game.bggId);

            // Get existing plays to avoid duplicates
            final existingPlays = await db.getPlaysForGame(widget.game.id!);

            // Convert existing plays to a set of date strings for quick lookup
            final existingPlayDates = existingPlays
                .map((p) => p.datePlayed.toIso8601String().substring(0, 10))
                .toSet();

            // Add plays from BGG that don't exist locally
            int addedCount = 0;
            for (final bggPlay in bggPlays) {
              final playDate = (bggPlay['datePlayed'] as DateTime)
                  .toIso8601String()
                  .substring(0, 10);

              if (!existingPlayDates.contains(playDate)) {
                final play = Play(
                  gameId: widget.game.id!,
                  datePlayed: bggPlay['datePlayed'] as DateTime,
                  won: bggPlay['won'] as bool?,
                );
                await db.insertPlay(play);
                addedCount++;
              }
            }

            if (addedCount > 0) {
              print('✅ Added $addedCount plays from BGG');
              // Reload plays to show the new data
              await _loadPlays();
            } else {
              print('✅ All BGG plays already synced');
            }
          } catch (e) {
            print('⚠️ Failed to sync plays from BGG: $e');
            // Don't fail the whole operation if plays sync fails
          }
        }
      }

      // Refresh the games provider so the list updates
      ref.read(gamesProvider.notifier).loadGames();

      setState(() {
        _detailedGame = updatedGame;
        _isLoadingDetails = false;
      });
    } catch (e) {
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
    if (!mounted) return;

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
    if (!mounted) return;

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

    // Small delay to ensure dialog is visible
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Use BGG ID for the NFC tag
      final success = await nfcService.writeGameId(widget.game.bggId);

      if (mounted) {
        Navigator.pop(context); // Close dialog

        if (success) {
          // Mark the game as having an NFC tag
          final db = ref.read(databaseServiceProvider);
          await db.updateGameHasNfcTag(widget.game.id!, true);

          // Update local state
          setState(() {
            final currentGame = _detailedGame ?? widget.game;
            _detailedGame = currentGame.copyWith(hasNfcTag: true);
          });

          // Reload games in provider to reflect the change
          ref.read(gamesProvider.notifier).loadGames();

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

          _InfoRow(
            icon: Icons.nfc,
            label: 'NFC Tag',
            value: game.hasNfcTag ? 'Assigned' : 'Unassigned',
            valueColor: game.hasNfcTag ? Colors.green : Colors.purple,
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

          // Location Editor (only for owned games)
          if (widget.isOwned) ...[
            LocationPicker(
              initialLocation: game.location,
              onLocationChanged: _saveLocation,
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
      ),
    );
  }

  Widget _buildScheduledTab() {
    if (_isLoadingScheduled) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schedule button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showScheduleDialog,
              icon: const Icon(Icons.event_available),
              label: const Text('Schedule Game Session'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Scheduled sessions list
          if (_scheduledGames.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No upcoming sessions scheduled',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button above to schedule a game session',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming Sessions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                ..._scheduledGames.map((scheduledGame) {
                  final dateStr = DateFormat('EEEE, MMM d, yyyy').format(scheduledGame.scheduledDateTime);
                  final timeStr = DateFormat('h:mm a').format(scheduledGame.scheduledDateTime);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.event,
                          color: Colors.blue[700],
                        ),
                      ),
                      title: Text(
                        dateStr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(timeStr),
                            ],
                          ),
                          if (scheduledGame.location != null && scheduledGame.location!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    scheduledGame.location!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                            onPressed: () => _editScheduledGame(scheduledGame),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.blue),
                            onPressed: () => _shareScheduledGame(scheduledGame),
                            tooltip: 'Share',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteScheduledGame(scheduledGame),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      isThreeLine: scheduledGame.location != null && scheduledGame.location!.isNotEmpty,
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLoansTab() {
    if (_isLoadingLoans) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeLoan = _loans.where((loan) => loan.isActive).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active loan banner
          if (activeLoan != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Currently Loaned',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Borrowed by: ${activeLoan.borrowerName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Since: ${DateFormat('MMM d, yyyy').format(activeLoan.loanDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Return Game'),
                            content: Text(
                              'Mark this game as returned from ${activeLoan.borrowerName}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Return'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          try {
                            await ref.read(loansProvider.notifier).returnGame(activeLoan.id!);
                            await _loadLoans();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Game marked as returned'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error returning game: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.assignment_return),
                      label: const Text('Mark as Returned'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Loan button (only if not currently loaned)
          if (activeLoan == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => LoanGameDialog(game: _detailedGame!),
                  );

                  if (result == true) {
                    await _loadLoans();
                  }
                },
                icon: const Icon(Icons.handshake),
                label: const Text('Loan Game'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Loan history
          Text(
            'Loan History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),

          if (_loans.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No loan history',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button above to loan this game',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: _loans.map((loan) {
                final isActive = loan.isActive;
                final daysLoaned = loan.isActive
                    ? DateTime.now().difference(loan.loanDate).inDays
                    : loan.returnDate!.difference(loan.loanDate).inDays;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.orange[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isActive ? Icons.handshake : Icons.assignment_return,
                        color: isActive ? Colors.orange[700] : Colors.green[700],
                      ),
                    ),
                    title: Text(
                      loan.borrowerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('Loaned: ${DateFormat('MMM d, yyyy').format(loan.loanDate)}'),
                          ],
                        ),
                        if (!isActive) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.assignment_return, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('Returned: ${DateFormat('MMM d, yyyy').format(loan.returnDate!)}'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '$daysLoaned ${daysLoaned == 1 ? 'day' : 'days'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: isActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete loan record',
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Loan Record'),
                                  content: Text(
                                    'Delete this loan record from ${loan.borrowerName}?',
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
                                  await ref.read(loansProvider.notifier).deleteLoan(loan.id!);
                                  await _loadLoans();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Loan record deleted'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error deleting loan: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                    isThreeLine: true,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTagsTab() {
    return SingleChildScrollView(
      child: GameTagsWidget(game: _detailedGame ?? widget.game),
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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGame,
            tooltip: 'Share Game',
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
          // Ownership Banner with toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: game.owned ? Colors.green[50] : Colors.orange[100],
            child: Row(
              children: [
                Icon(
                  game.owned ? Icons.check_circle : Icons.info_outline,
                  color: game.owned ? Colors.green[700] : Colors.orange[900],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    game.owned ? 'In your collection' : 'Not in your collection',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: game.owned ? Colors.green[700] : Colors.orange[900],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Wishlist button (only for non-owned games)
                if (!game.owned)
                  TextButton.icon(
                    onPressed: _toggleWishlist,
                    icon: Icon(
                      game.wishlisted ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: game.wishlisted ? Colors.red : Colors.grey[700],
                    ),
                    label: Text(
                      game.wishlisted ? 'Wishlisted' : 'Wishlist',
                      style: TextStyle(
                        fontSize: 12,
                        color: game.wishlisted ? Colors.red : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                if (!game.owned) const SizedBox(width: 4),
                // Toggle owned button
                TextButton.icon(
                  onPressed: _toggleOwned,
                  icon: Icon(
                    game.owned ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    size: 18,
                    color: game.owned ? Colors.red[700] : Colors.green[700],
                  ),
                  label: Text(
                    game.owned ? 'Remove' : 'Add',
                    style: TextStyle(
                      fontSize: 12,
                      color: game.owned ? Colors.red[700] : Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
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
              Tab(icon: Icon(Icons.info_outline)),
              Tab(icon: Icon(Icons.history)),
              Tab(icon: Icon(Icons.event)),
              Tab(icon: Icon(Icons.handshake_outlined)),
              Tab(icon: Icon(Icons.label_outline)),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(game),
                _buildPlayHistoryTab(),
                _buildScheduledTab(),
                _buildLoansTab(),
                _buildTagsTab(),
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
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: valueColor ?? Colors.grey[600]),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
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
