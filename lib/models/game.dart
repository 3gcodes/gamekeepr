import 'dart:convert';

class ExpansionReference {
  final int bggId;
  final String name;

  ExpansionReference({
    required this.bggId,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'bggId': bggId,
      'name': name,
    };
  }

  factory ExpansionReference.fromMap(Map<String, dynamic> map) {
    return ExpansionReference(
      bggId: map['bggId'] as int,
      name: map['name'] as String,
    );
  }
}

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
  final List<String>? categories;
  final List<String>? mechanics;
  final ExpansionReference? baseGame; // If this is an expansion, reference to base game
  final List<ExpansionReference>? expansions; // If this is a base game, list of expansions
  final bool owned; // Whether this game is in the user's collection
  final bool wishlisted; // Whether this game is on the user's wishlist
  final bool savedForLater; // Whether this game is saved for later
  final bool hasNfcTag; // Whether an NFC tag has been assigned to this game

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
    this.categories,
    this.mechanics,
    this.baseGame,
    this.expansions,
    this.owned = true,
    this.wishlisted = false,
    this.savedForLater = false,
    this.hasNfcTag = false,
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
      'categories': categories != null ? jsonEncode(categories) : null,
      'mechanics': mechanics != null ? jsonEncode(mechanics) : null,
      'base_game': baseGame != null ? jsonEncode(baseGame!.toMap()) : null,
      'expansions': expansions != null ? jsonEncode(expansions!.map((e) => e.toMap()).toList()) : null,
      'owned': owned ? 1 : 0,
      'wishlisted': wishlisted ? 1 : 0,
      'saved_for_later': savedForLater ? 1 : 0,
      'has_nfc_tag': hasNfcTag ? 1 : 0,
    };
  }

  factory Game.fromMap(Map<String, dynamic> map) {
    final baseGameJson = map['base_game'] as String?;

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
      categories: map['categories'] != null
          ? List<String>.from(jsonDecode(map['categories'] as String))
          : null,
      mechanics: map['mechanics'] != null
          ? List<String>.from(jsonDecode(map['mechanics'] as String))
          : null,
      baseGame: baseGameJson != null
          ? ExpansionReference.fromMap(jsonDecode(baseGameJson))
          : null,
      expansions: map['expansions'] != null
          ? (jsonDecode(map['expansions'] as String) as List)
              .map((e) => ExpansionReference.fromMap(e as Map<String, dynamic>))
              .toList()
          : null,
      owned: map['owned'] == null ? true : (map['owned'] as int) == 1,
      wishlisted: map['wishlisted'] == null ? false : (map['wishlisted'] as int) == 1,
      savedForLater: map['saved_for_later'] == null ? false : (map['saved_for_later'] as int) == 1,
      hasNfcTag: map['has_nfc_tag'] == null ? false : (map['has_nfc_tag'] as int) == 1,
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
    List<String>? categories,
    List<String>? mechanics,
    ExpansionReference? baseGame,
    List<ExpansionReference>? expansions,
    bool? owned,
    bool? wishlisted,
    bool? savedForLater,
    bool? hasNfcTag,
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
      categories: categories ?? this.categories,
      mechanics: mechanics ?? this.mechanics,
      baseGame: baseGame ?? this.baseGame,
      expansions: expansions ?? this.expansions,
      owned: owned ?? this.owned,
      wishlisted: wishlisted ?? this.wishlisted,
      savedForLater: savedForLater ?? this.savedForLater,
      hasNfcTag: hasNfcTag ?? this.hasNfcTag,
    );
  }

  String get playersInfo {
    if (minPlayers == null && maxPlayers == null) return 'Unknown';
    if (minPlayers == null) return '$maxPlayers players';
    if (maxPlayers == null) return '$minPlayers players';
    if (minPlayers == maxPlayers) return '$minPlayers players';
    return '$minPlayers-$maxPlayers players';
  }

  String get playtimeInfo {
    if (minPlaytime == null && maxPlaytime == null) return 'Unknown';
    if (minPlaytime == null) return '$maxPlaytime min';
    if (maxPlaytime == null) return '$minPlaytime min';
    if (minPlaytime == maxPlaytime) return '$minPlaytime min';
    return '$minPlaytime-$maxPlaytime min';
  }
}
