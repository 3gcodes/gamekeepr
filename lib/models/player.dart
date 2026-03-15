class Player {
  final int? id;
  final String name;
  final String? bggUsername;
  final DateTime createdAt;

  Player({
    this.id,
    required this.name,
    this.bggUsername,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bgg_username': bggUsername,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as int?,
      name: map['name'] as String,
      bggUsername: map['bgg_username'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Player copyWith({
    int? id,
    String? name,
    String? bggUsername,
    DateTime? createdAt,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      bggUsername: bggUsername ?? this.bggUsername,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
