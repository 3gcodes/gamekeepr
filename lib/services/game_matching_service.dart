import 'package:gamekeepr/models/game_match_result.dart';
import 'package:gamekeepr/services/database_service.dart';
import 'package:string_similarity/string_similarity.dart';

class GameMatchingService {
  final DatabaseService _databaseService;

  GameMatchingService({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  /// Matches extracted text from an image against the user's game collection
  /// Returns a list of GameMatchResults sorted by confidence (highest first)
  Future<List<GameMatchResult>> matchGames({
    required List<String> extractedTexts,
    double minimumConfidence = 0.3,
  }) async {
    if (extractedTexts.isEmpty) {
      return [];
    }

    // Get all owned games from database
    final allGames = await _databaseService.getAllGames();

    if (allGames.isEmpty) {
      return [];
    }

    // Map to track best match for each game
    final Map<int, GameMatchResult> bestMatches = {};

    // For each extracted text, find matching games
    for (final extractedText in extractedTexts) {
      final cleanedText = _cleanText(extractedText);

      if (cleanedText.isEmpty || cleanedText.length < 3) {
        continue; // Skip very short texts
      }

      // Check against each game
      for (final game in allGames) {
        final gameName = _cleanText(game.name);

        // Calculate similarity
        final similarity = cleanedText.similarityTo(gameName);

        // Also check if extracted text is contained in game name or vice versa
        final containsMatch = _calculateContainsMatch(cleanedText, gameName);

        // Use the higher of the two scores
        final confidence = similarity > containsMatch ? similarity : containsMatch;

        if (confidence >= minimumConfidence) {
          // Check if this is a better match than what we already have for this game
          final existingMatch = bestMatches[game.bggId];
          if (existingMatch == null || confidence > existingMatch.confidence) {
            bestMatches[game.bggId] = GameMatchResult(
              game: game,
              confidence: confidence,
              matchedText: extractedText,
            );
          }
        }
      }
    }

    // Convert to list and sort by confidence (highest first)
    final results = bestMatches.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return results;
  }

  /// Cleans text for better matching
  String _cleanText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Calculates a match score based on substring containment
  /// Returns a value between 0.0 and 1.0
  double _calculateContainsMatch(String text1, String text2) {
    final shorter = text1.length < text2.length ? text1 : text2;
    final longer = text1.length < text2.length ? text2 : text1;

    if (longer.contains(shorter)) {
      // If one string contains the other, return a high score
      // based on how much of the longer string is matched
      return shorter.length / longer.length;
    }

    // Check for partial word matches
    final words1 = text1.split(' ');
    final words2 = text2.split(' ');

    int matchingWords = 0;
    for (final word1 in words1) {
      if (word1.length < 3) continue; // Skip short words
      for (final word2 in words2) {
        if (word1 == word2 || word1.contains(word2) || word2.contains(word1)) {
          matchingWords++;
          break;
        }
      }
    }

    if (matchingWords == 0) return 0.0;

    // Return a score based on matching words vs total words
    final totalWords = words1.length > words2.length ? words1.length : words2.length;
    return matchingWords / totalWords * 0.8; // Cap at 0.8 for partial word matches
  }
}
