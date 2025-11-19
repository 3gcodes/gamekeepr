import 'game.dart';

class GameWithPlayInfo {
  final Game game;
  final DateTime lastPlayed;
  final int playCount;
  final int wins;
  final int losses;

  GameWithPlayInfo({
    required this.game,
    required this.lastPlayed,
    required this.playCount,
    required this.wins,
    required this.losses,
  });

  factory GameWithPlayInfo.fromMap(Map<String, dynamic> map) {
    // Extract game data from the map
    final game = Game.fromMap(map);

    // Extract play info
    final lastPlayed = DateTime.parse(map['last_played'] as String);
    final playCount = map['play_count'] as int;
    final wins = map['wins'] as int? ?? 0;
    final losses = map['losses'] as int? ?? 0;

    return GameWithPlayInfo(
      game: game,
      lastPlayed: lastPlayed,
      playCount: playCount,
      wins: wins,
      losses: losses,
    );
  }
}
