class PlayPlayer {
  final int? id;
  final int playId;
  final int playerId;
  final bool winner;
  final String? score;

  PlayPlayer({
    this.id,
    required this.playId,
    required this.playerId,
    this.winner = false,
    this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'play_id': playId,
      'player_id': playerId,
      'winner': winner ? 1 : 0,
      'score': score,
    };
  }

  factory PlayPlayer.fromMap(Map<String, dynamic> map) {
    return PlayPlayer(
      id: map['id'] as int?,
      playId: map['play_id'] as int,
      playerId: map['player_id'] as int,
      winner: (map['winner'] as int?) == 1,
      score: map['score'] as String?,
    );
  }

  PlayPlayer copyWith({
    int? id,
    int? playId,
    int? playerId,
    bool? winner,
    String? score,
  }) {
    return PlayPlayer(
      id: id ?? this.id,
      playId: playId ?? this.playId,
      playerId: playerId ?? this.playerId,
      winner: winner ?? this.winner,
      score: score ?? this.score,
    );
  }
}
