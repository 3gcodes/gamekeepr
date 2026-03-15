import 'play.dart';
import 'player.dart';

class PlayerWithWinStatus {
  final Player player;
  final bool winner;

  PlayerWithWinStatus({
    required this.player,
    this.winner = false,
  });
}

class PlayWithPlayers {
  final Play play;
  final List<PlayerWithWinStatus> players;

  PlayWithPlayers({
    required this.play,
    this.players = const [],
  });

  List<PlayerWithWinStatus> get winners =>
      players.where((p) => p.winner).toList();

  List<String> get playerNames =>
      players.map((p) => p.player.name).toList();

  List<String> get winnerNames =>
      winners.map((p) => p.player.name).toList();
}
