class ScheduledGame {
  final int? id;
  final int gameId; // Reference to game's local id
  final DateTime scheduledDateTime;
  final String? location;
  final DateTime createdAt;

  ScheduledGame({
    this.id,
    required this.gameId,
    required this.scheduledDateTime,
    this.location,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_id': gameId,
      'scheduled_date_time': scheduledDateTime.toIso8601String(),
      'location': location,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScheduledGame.fromMap(Map<String, dynamic> map) {
    return ScheduledGame(
      id: map['id'] as int?,
      gameId: map['game_id'] as int,
      scheduledDateTime: DateTime.parse(map['scheduled_date_time'] as String),
      location: map['location'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  ScheduledGame copyWith({
    int? id,
    int? gameId,
    DateTime? scheduledDateTime,
    String? location,
    DateTime? createdAt,
  }) {
    return ScheduledGame(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if this scheduled game is in the future
  bool get isFuture => scheduledDateTime.isAfter(DateTime.now());
}
