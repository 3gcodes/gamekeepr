class Play {
  final int? id;
  final int gameId;
  final DateTime datePlayed;
  final DateTime createdAt;
  final bool? won;
  final bool syncedFromBgg;

  Play({
    this.id,
    required this.gameId,
    required this.datePlayed,
    DateTime? createdAt,
    this.won,
    this.syncedFromBgg = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_id': gameId,
      'date_played': datePlayed.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'won': won == null ? null : (won! ? 1 : 0),
      'synced_from_bgg': syncedFromBgg ? 1 : 0,
    };
  }

  factory Play.fromMap(Map<String, dynamic> map) {
    return Play(
      id: map['id'] as int?,
      gameId: map['game_id'] as int,
      datePlayed: DateTime.parse(map['date_played'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      won: map['won'] == null ? null : (map['won'] as int) == 1,
      syncedFromBgg: (map['synced_from_bgg'] as int?) == 1,
    );
  }

  Play copyWith({
    int? id,
    int? gameId,
    DateTime? datePlayed,
    DateTime? createdAt,
    bool? won,
    bool? syncedFromBgg,
  }) {
    return Play(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      datePlayed: datePlayed ?? this.datePlayed,
      createdAt: createdAt ?? this.createdAt,
      won: won ?? this.won,
      syncedFromBgg: syncedFromBgg ?? this.syncedFromBgg,
    );
  }
}
