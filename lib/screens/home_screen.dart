import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_state_providers.dart';
import 'games_tab_screen.dart';
import 'collectibles_screen.dart';
import 'more_tab_screen.dart';
import 'nfc_scan_screen.dart';
import 'nfc_record_play_screen.dart';
import 'nfc_loan_game_screen.dart';
import 'write_shelf_tag_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainBottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          GamesTabScreen(),
          CollectiblesScreen(),
          MoreTabScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(mainBottomNavIndexProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.casino),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Collectibles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'nfc_fab',
        onPressed: () => _showNfcMenu(context),
        tooltip: 'NFC Actions',
        child: const Icon(Icons.nfc),
      ),
    );
  }

  void _showNfcMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.nfc),
              title: const Text('Scan Tag'),
              subtitle: const Text('Read an NFC tag'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NfcScanScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Record Play'),
              subtitle: const Text('Log a game session via NFC'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NfcRecordPlayScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake),
              title: const Text('Loan Game'),
              subtitle: const Text('Lend a game via NFC'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NfcLoanGameScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Write Shelf Tag'),
              subtitle: const Text('Program an NFC tag for a shelf'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WriteShelfTagScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
