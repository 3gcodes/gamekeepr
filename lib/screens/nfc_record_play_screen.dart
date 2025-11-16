import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/play.dart';
import 'game_details_screen.dart';

class NfcRecordPlayScreen extends ConsumerStatefulWidget {
  const NfcRecordPlayScreen({super.key});

  @override
  ConsumerState<NfcRecordPlayScreen> createState() => _NfcRecordPlayScreenState();
}

class _NfcRecordPlayScreenState extends ConsumerState<NfcRecordPlayScreen> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  Future<void> _startScanning() async {
    final nfcService = ref.read(nfcServiceProvider);

    // Skip availability check - isAvailable() has bugs on some iOS versions
    // The native dialog appearing confirms NFC is actually working
    print('📱 Skipping NFC availability check...');

    setState(() {
      _isScanning = true;
    });

    try {
      final gameId = await nfcService.readGameId();

      if (gameId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read game ID from tag'),
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
      final game = await ref.read(gamesProvider.notifier).getGameByBggId(gameId);

      if (mounted) {
        if (game != null && game.id != null) {
          // Record the play with today's date
          final db = ref.read(databaseServiceProvider);
          final play = Play(
            gameId: game.id!,
            datePlayed: DateTime.now(),
          );

          await db.insertPlay(play);

          final formattedDate = DateFormat('MMM d, yyyy').format(DateTime.now());

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Play recorded for ${game.name} on $formattedDate'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Navigate to game details
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailsScreen(game: game),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game with ID $gameId not found in collection'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording play: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }

    setState(() {
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Play via NFC'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 120,
              color: _isScanning ? Colors.green : Colors.grey[400],
            ),
            const SizedBox(height: 32),
            Text(
              _isScanning
                  ? 'Hold your device near the NFC tag\nto record a play for today'
                  : 'Ready to record play',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isScanning) const CircularProgressIndicator(),
            if (!_isScanning)
              ElevatedButton(
                onPressed: _startScanning,
                child: const Text('Scan Again'),
              ),
          ],
        ),
      ),
    );
  }
}
