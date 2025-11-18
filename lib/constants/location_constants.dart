/// Constants for game location management
class LocationConstants {
  // Shelf letters A-Z (26 shelves)
  static const List<String> shelves = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  // Bay numbers 1-20
  static const int maxBays = 20;
  static List<int> get bays => List.generate(maxBays, (index) => index + 1);

  /// Formats a shelf and bay into a location string (e.g., "A5", "B12")
  static String formatLocation(String shelf, int bay) {
    return '$shelf$bay';
  }

  /// Parses a location string into shelf and bay components
  /// Returns null if the format is invalid
  static LocationParts? parseLocation(String location) {
    if (location.isEmpty) return null;

    // Extract shelf letter (first character)
    final shelf = location[0].toUpperCase();
    if (!shelves.contains(shelf)) return null;

    // Extract bay number (remaining characters)
    final bayStr = location.substring(1);
    final bay = int.tryParse(bayStr);
    if (bay == null || bay < 1 || bay > maxBays) return null;

    return LocationParts(shelf: shelf, bay: bay);
  }

  /// Validates if a location string is in the correct format
  static bool isValidLocation(String location) {
    return parseLocation(location) != null;
  }
}

/// Data class for location components
class LocationParts {
  final String shelf;
  final int bay;

  LocationParts({required this.shelf, required this.bay});

  @override
  String toString() => LocationConstants.formatLocation(shelf, bay);
}
