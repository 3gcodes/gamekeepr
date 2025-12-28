import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/barcode_service.dart';
import '../providers/games_provider.dart';
import 'game_details_screen.dart';
import 'bgg_search_screen.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final BarcodeService _barcodeService = BarcodeService();
  bool _isProcessing = false;
  String? _statusMessage;
  String? _lastScannedBarcode; // Track last scanned barcode to prevent duplicates

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showErrorAndClose(String errorMessage) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Failed'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close scanner
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBarcode(String barcode) async {
    if (_isProcessing) return;

    // Prevent scanning the same barcode multiple times
    if (_lastScannedBarcode == barcode) return;

    _lastScannedBarcode = barcode;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Looking up barcode...';
    });

    try {
      // First, lookup the barcode to get product name
      final result = await _barcodeService.lookupBarcode(barcode);

      if (!result.found) {
        // Barcode not found or error occurred - show error and close
        if (mounted) {
          _showErrorAndClose(result.errorMessage ?? 'Unknown error occurred');
        }
        return;
      }

      final productName = result.productName!;

      setState(() {
        _statusMessage = 'Found: $productName';
      });

      // Check if game exists in local library
      final gamesAsync = ref.read(gamesProvider);
      await gamesAsync.when(
        data: (games) async {
          // Search for the game in local library (case-insensitive)
          final localGame = games.where((g) {
            return g.name.toLowerCase().contains(productName.toLowerCase()) ||
                productName.toLowerCase().contains(g.name.toLowerCase());
          }).firstOrNull;

          if (localGame != null) {
            // Found in local library - navigate to game details
            if (mounted) {
              Navigator.pop(context); // Close scanner
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameDetailsScreen(
                    game: localGame,
                    isOwned: localGame.owned,
                  ),
                ),
              );
            }
          } else {
            // Not in library - search BGG
            if (mounted) {
              setState(() {
                _statusMessage = 'Searching BoardGameGeek...';
              });

              if (mounted) {
                Navigator.pop(context); // Close scanner
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BggSearchScreen(
                      initialQuery: productName,
                    ),
                  ),
                );
              }
            }
          }
        },
        loading: () async {
          // If games are still loading, just search BGG
          if (mounted) {
            setState(() {
              _statusMessage = 'Searching BoardGameGeek...';
            });

            if (mounted) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BggSearchScreen(
                    initialQuery: productName,
                  ),
                ),
              );
            }
          }
        },
        error: (_, __) async {
          // On error, just search BGG
          if (mounted) {
            setState(() {
              _statusMessage = 'Searching BoardGameGeek...';
            });

            if (mounted) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BggSearchScreen(
                    initialQuery: productName,
                  ),
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        _showErrorAndClose('Unexpected error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Barcode Scanner'),
                  content: const Text(
                    'Point your camera at a board game barcode (UPC/EAN).\n\n'
                    'The app will:\n'
                    '1. Look up the product name\n'
                    '2. Check your local library\n'
                    '3. Search BoardGameGeek if not found\n\n'
                    'Free tier: 100 scans per day',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !_isProcessing) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null) {
                  _handleBarcode(barcode.rawValue!);
                }
              }
            },
          ),

          // Scanning frame overlay
          Center(
            child: Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Status message
          if (_statusMessage != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    if (_isProcessing) const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Instructions
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'Position barcode within the frame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                backgroundColor: Colors.black.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
