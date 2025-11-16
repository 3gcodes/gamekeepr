class Game {
  final int? id; // Local database ID
  final int bggId; // Board Game Geek ID
  final String name;
  final String? description;
  final String? imageUrl;
  final String? thumbnailUrl;
  final int? yearPublished;
  final int? minPlayers;
  final int? maxPlayers;
  final int? minPlaytime;
  final int? maxPlaytime;
  final double? averageRating;
  final String? location; // Shelf location as generic string
  final DateTime? lastSynced;

  Game({
    this.id,
    required this.bggId,
    required this.name,
    this.description,
    this.imageUrl,
    this.thumbnailUrl,
    this.yearPublished,
    this.minPlayers,
    this.maxPlayers,
    this.minPlaytime,
    this.maxPlaytime,
    this.averageRating,
    this.location,
    this.lastSynced,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bgg_id': bggId,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'year_published': yearPublished,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      'min_playtime': minPlaytime,
      'max_playtime': maxPlaytime,
      'average_rating': averageRating,
      'location': location,
      'last_synced': lastSynced?.toIso8601String(),
    };
  }

  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'] as int?,
      bggId: map['bgg_id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      yearPublished: map['year_published'] as int?,
      minPlayers: map['min_players'] as int?,
      maxPlayers: map['max_players'] as int?,
      minPlaytime: map['min_playtime'] as int?,
      maxPlaytime: map['max_playtime'] as int?,
      averageRating: map['average_rating'] as double?,
      location: map['location'] as String?,
      lastSynced: map['last_synced'] != null
          ? DateTime.parse(map['last_synced'] as String)
          : null,
    );
  }

  Game copyWith({
    int? id,
    int? bggId,
    String? name,
    String? description,
    String? imageUrl,
    String? thumbnailUrl,
    int? yearPublished,
    int? minPlayers,
    int? maxPlayers,
    int? minPlaytime,
    int? maxPlaytime,
    double? averageRating,
    String? location,
    DateTime? lastSynced,
  }) {
    return Game(
      id: id ?? this.id,
      bggId: bggId ?? this.bggId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      yearPublished: yearPublished ?? this.yearPublished,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      minPlaytime: minPlaytime ?? this.minPlaytime,
      maxPlaytime: maxPlaytime ?? this.maxPlaytime,
      averageRating: averageRating ?? this.averageRating,
      location: location ?? this.location,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  String get playersInfo {
    if (minPlayers == null && maxPlayers == null) return 'Unknown';
    if (minPlayers == maxPlayers) return '$minPlayers players';
    return '$minPlayers-$maxPlayers players';
  }

  String get playtimeInfo {
    if (minPlaytime == null && maxPlaytime == null) return 'Unknown';
    if (minPlaytime == maxPlaytime) return '$minPlaytime min';
    return '$minPlaytime-$maxPlaytime min';
  }
}
