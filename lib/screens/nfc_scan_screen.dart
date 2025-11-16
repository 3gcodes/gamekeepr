import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'game_details_screen.dart';

class NfcScanScreen extends ConsumerStatefulWidget {
  const NfcScanScreen({super.key});

  @override
  ConsumerState<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends ConsumerState<NfcScanScreen> {
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
        if (game != null) {
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
            content: Text('Error reading NFC tag: $e'),
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
        title: const Text('Scan NFC Tag'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.nfc,
              size: 120,
              color: _isScanning ? Colors.blue : Colors.grey[400],
            ),
            const SizedBox(height: 32),
            Text(
              _isScanning ? 'Hold your device near the NFC tag' : 'Ready to scan',
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
