import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../screens/game_details_screen.dart';

class DeepLinkService {
  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  DeepLinkService({required this.navigatorKey});

  Future<void> init() async {
    // Handle cold start
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleUri(initialUri);
      });
    }

    // Handle warm resume
    _subscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _handleUri(Uri uri) {
    debugPrint('Deep link received: $uri');

    if (uri.scheme != 'gamekeepr') return;

    // gamekeepr://game/456 parses as host="game", pathSegments=["456"]
    if (uri.host == 'game' && uri.pathSegments.isNotEmpty) {
      final bggId = int.tryParse(uri.pathSegments[0]);
      if (bggId == null) {
        debugPrint('Deep link: non-numeric bggId "${uri.pathSegments[0]}"');
        return;
      }
      _navigateToGame(bggId);
    } else {
      debugPrint('Deep link: unrecognized host "${uri.host}" path "${uri.path}"');
    }
  }

  Future<void> _navigateToGame(int bggId) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final context = navigator.context;

    try {
      final game = await DatabaseService.instance.getGameByBggId(bggId);

      if (game == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game with BGG ID $bggId not found in collection'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => GameDetailsScreen(
            game: game,
            isOwned: game.owned,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
