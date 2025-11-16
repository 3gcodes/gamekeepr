class Play {
  final int? id;
  final int gameId;
  final DateTime datePlayed;
  final DateTime createdAt;

  Play({
    this.id,
    required this.gameId,
    required this.datePlayed,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_id': gameId,
      'date_played': datePlayed.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Play.fromMap(Map<String, dynamic> map) {
    return Play(
      id: map['id'] as int?,
      gameId: map['game_id'] as int,
      datePlayed: DateTime.parse(map['date_played'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Play copyWith({
    int? id,
    int? gameId,
    DateTime? datePlayed,
    DateTime? createdAt,
  }) {
    return Play(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      datePlayed: datePlayed ?? this.datePlayed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
