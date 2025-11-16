import 'game.dart';

class GameWithPlayInfo {
  final Game game;
  final DateTime lastPlayed;
  final int playCount;

  GameWithPlayInfo({
    required this.game,
    required this.lastPlayed,
    required this.playCount,
  });

  factory GameWithPlayInfo.fromMap(Map<String, dynamic> map) {
    // Extract game data from the map
    final game = Game.fromMap(map);

    // Extract play info
    final lastPlayed = DateTime.parse(map['last_played'] as String);
    final playCount = map['play_count'] as int;

    return GameWithPlayInfo(
      game: game,
      lastPlayed: lastPlayed,
      playCount: playCount,
    );
  }
}
