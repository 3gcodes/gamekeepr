import 'dart:convert';

enum CollectibleType {
  MINIATURE,
  // Future types can be added here:
  // TERRAIN,
  // DICE_SET,
  // PLAYMAT,
  // ORGANIZER,
}

extension CollectibleTypeExtension on CollectibleType {
  String get displayName {
    switch (this) {
      case CollectibleType.MINIATURE:
        return 'Miniature';
    }
  }

  String get value {
    switch (this) {
      case CollectibleType.MINIATURE:
        return 'MINIATURE';
    }
  }

  static CollectibleType fromString(String value) {
    switch (value) {
      case 'MINIATURE':
        return CollectibleType.MINIATURE;
      default:
        throw ArgumentError('Unknown CollectibleType: $value');
    }
  }
}

class Collectible {
  final int? id; // Local database ID
  final CollectibleType type;
  final String name;
  final int? gameId; // Optional reference to a game
  final String? manufacturer;
  final String? description;
  final bool painted; // For miniatures; can be repurposed for other types
  final int quantity;
  final String? location; // Shelf location as generic string
  final bool hasNfcTag;
  final List<String> images; // Multiple image paths (max 3)
  final int coverImageIndex; // Index of the cover image (0-2)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Collectible({
    this.id,
    required this.type,
    required this.name,
    this.gameId,
    this.manufacturer,
    this.description,
    this.painted = false,
    this.quantity = 1,
    this.location,
    this.hasNfcTag = false,
    this.images = const [],
    this.coverImageIndex = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'name': name,
      'game_id': gameId,
      'manufacturer': manufacturer,
      'description': description,
      'painted': painted ? 1 : 0,
      'quantity': quantity,
      'location': location,
      'has_nfc_tag': hasNfcTag ? 1 : 0,
      'images': jsonEncode(images),
      'cover_image_index': coverImageIndex,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Collectible.fromMap(Map<String, dynamic> map) {
    // Parse images from JSON, fallback to old image_url for backward compatibility
    List<String> imagesList = [];
    if (map['images'] != null && map['images'] is String && (map['images'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(map['images'] as String);
        imagesList = List<String>.from(decoded);
      } catch (e) {
        print('Error parsing images JSON: $e');
      }
    } else if (map['image_url'] != null && (map['image_url'] as String).isNotEmpty) {
      // Backward compatibility: convert old single image_url to images array
      imagesList = [map['image_url'] as String];
    }

    return Collectible(
      id: map['id'] as int?,
      type: CollectibleTypeExtension.fromString(map['type'] as String),
      name: map['name'] as String,
      gameId: map['game_id'] as int?,
      manufacturer: map['manufacturer'] as String?,
      description: map['description'] as String?,
      painted: map['painted'] == null ? false : (map['painted'] as int) == 1,
      quantity: map['quantity'] as int? ?? 1,
      location: map['location'] as String?,
      hasNfcTag: map['has_nfc_tag'] == null ? false : (map['has_nfc_tag'] as int) == 1,
      images: imagesList,
      coverImageIndex: map['cover_image_index'] as int? ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Collectible copyWith({
    int? id,
    CollectibleType? type,
    String? name,
    int? gameId,
    String? manufacturer,
    String? description,
    bool? painted,
    int? quantity,
    String? location,
    bool? hasNfcTag,
    List<String>? images,
    int? coverImageIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Collectible(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      gameId: gameId ?? this.gameId,
      manufacturer: manufacturer ?? this.manufacturer,
      description: description ?? this.description,
      painted: painted ?? this.painted,
      quantity: quantity ?? this.quantity,
      location: location ?? this.location,
      hasNfcTag: hasNfcTag ?? this.hasNfcTag,
      images: images ?? this.images,
      coverImageIndex: coverImageIndex ?? this.coverImageIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  String get typeDisplayName => type.displayName;

  bool get isPainted => type == CollectibleType.MINIATURE && painted;

  bool get hasGame => gameId != null;

  // Get the cover image URL (for backward compatibility and convenience)
  String? get imageUrl {
    if (images.isEmpty) return null;
    if (coverImageIndex >= 0 && coverImageIndex < images.length) {
      return images[coverImageIndex];
    }
    return images.first;
  }

  // Check if collectible has any images
  bool get hasImages => images.isNotEmpty;
}
