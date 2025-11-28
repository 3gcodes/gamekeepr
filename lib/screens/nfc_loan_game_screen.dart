import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/loan_game_dialog.dart';

class NfcLoanGameScreen extends ConsumerStatefulWidget {
  const NfcLoanGameScreen({super.key});

  @override
  ConsumerState<NfcLoanGameScreen> createState() => _NfcLoanGameScreenState();
}

class _NfcLoanGameScreenState extends ConsumerState<NfcLoanGameScreen> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  Future<void> _startScanning() async {
    final nfcService = ref.read(nfcServiceProvider);

    setState(() {
      _isScanning = true;
    });

    try {
      final tagData = await nfcService.readTag();

      if (tagData == null || tagData['type'] != 'game') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please scan a game tag'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Lookup game by BGG ID
      final gameId = tagData['data'] as int;
      final game = await ref.read(gamesProvider.notifier).getGameByBggId(gameId);

      if (mounted) {
        if (game != null) {
          // Mark game as having an NFC tag if not already set
          if (!game.hasNfcTag && game.id != null) {
            final db = ref.read(databaseServiceProvider);
            await db.updateGameHasNfcTag(game.id!, true);
            // Reload games to reflect the change
            ref.read(gamesProvider.notifier).loadGames();
          }

          // Show loan dialog
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => LoanGameDialog(game: game),
          );

          if (mounted) {
            if (result == true) {
              // Loan was created successfully
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${game.name} loaned successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            Navigator.pop(context);
          }
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
            content: Text('Error reading NFC tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Game via NFC'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.handshake,
              size: 120,
              color: _isScanning ? Colors.green : Colors.grey[400],
            ),
            const SizedBox(height: 32),
            Text(
              _isScanning ? 'Hold your device near the game tag' : 'Ready to scan',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the NFC tag on the game you want to loan',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
