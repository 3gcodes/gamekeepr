import 'package:gamekeepr/models/game.dart';

class GameMatchResult {
  final Game game;
  final double confidence; // 0.0 to 1.0
  final String matchedText; // The text that matched

  GameMatchResult({
    required this.game,
    required this.confidence,
    required this.matchedText,
  });

  // Helper to determine if this is a strong match
  bool get isStrongMatch => confidence >= 0.7;
  bool get isMediumMatch => confidence >= 0.5 && confidence < 0.7;
  bool get isWeakMatch => confidence < 0.5;
}
