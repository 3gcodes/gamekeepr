import 'dart:async';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../models/game.dart';

class BggService {
  static const String _baseUrl = 'https://boardgamegeek.com/xmlapi2';

  // Store bearer token for API v2 authenticated requests
  String? _bearerToken;

  /// Set bearer token for API v2 authenticated requests
  void setBearerToken(String token) {
    _bearerToken = token;
  }

  /// Check if bearer token is set
  bool get hasToken => _bearerToken != null && _bearerToken!.isNotEmpty;

  /// Fetch collection for a given username
  Future<List<Game>> fetchCollection(String username, {int retryCount = 0}) async {
    if (username.isEmpty) {
      throw Exception('Username cannot be empty');
    }

    if (!hasToken) {
      throw Exception('Please set your BGG API token in settings');
    }

    // Request collection
    final collectionUrl = '$_baseUrl/collection?username=$username&own=1';

    print('🔍 BGG API Request: $collectionUrl');
    print('🔍 Using bearer token: ${_bearerToken != null}');
    print('🔍 Retry count: $retryCount');

    // Create headers with bearer token
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/xml',
      'Authorization': 'Bearer $_bearerToken',
    };

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: headers,
    ));

    final response = await dio.get(
      collectionUrl,
      options: Options(
        validateStatus: (status) => status! < 500,
      ),
    );

    print('📡 Response Status: ${response.statusCode}');

    if (response.statusCode == 202) {
      // Collection is being processed, wait and retry
      if (retryCount >= 10) {
        throw Exception('Collection is still being processed after multiple retries. Please try again later.');
      }
      print('⏳ Collection queued, waiting 5 seconds before retry...');
      await Future.delayed(const Duration(seconds: 5));
      return fetchCollection(username, retryCount: retryCount + 1);
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid API token. Please check your settings.');
    }

    if (response.statusCode != 200) {
      final responseData = response.data?.toString() ?? '';
      print('❌ Response Body: ${responseData.substring(0, responseData.length > 500 ? 500 : responseData.length)}');
      throw Exception('Failed to fetch collection: ${response.statusCode}\nURL: $collectionUrl');
    }

    final document = XmlDocument.parse(response.data.toString());
    final items = document.findAllElements('item');

    if (items.isEmpty) {
      return [];
    }

    // Parse games directly from collection response
    final games = <Game>[];
    for (final item in items) {
      try {
        final game = _parseGameFromCollectionXml(item);
        games.add(game);
      } catch (e) {
        print('Error parsing game from collection: $e');
        // Continue with other games
      }
    }

    print('✅ Parsed ${games.length} games from collection');
    return games;
  }

  /// Fetch detailed information for multiple games
  /// Uses bearer token if available for authenticated requests
  Future<List<Game>> _fetchGameDetails(List<String?> gameIds, {int retryCount = 0}) async {
    if (gameIds.isEmpty) return [];

    // BGG API allows multiple IDs separated by commas
    final idsString = gameIds.join(',');
    final detailsUrl = '$_baseUrl/thing?id=$idsString&stats=1';

    print('🔍 BGG API Details Request: $detailsUrl');
    print('🔍 Using bearer token: ${_bearerToken != null}');

    // Create a Dio instance with bearer token if available
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/xml',
    };

    // Add bearer token if available
    if (_bearerToken != null) {
      headers['Authorization'] = 'Bearer $_bearerToken';
    }

    final cleanDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: headers,
    ));

    final response = await cleanDio.get(
      detailsUrl,
      options: Options(
        validateStatus: (status) => status! < 500,
      ),
    );

    print('📡 Details Response Status: ${response.statusCode}');

    if (response.statusCode == 202) {
      // Details are being processed, wait and retry
      if (retryCount >= 10) {
        throw Exception('Game details still being processed after multiple retries. Please try again later.');
      }
      print('⏳ Details queued, waiting 3 seconds before retry...');
      await Future.delayed(const Duration(seconds: 3));
      return _fetchGameDetails(gameIds, retryCount: retryCount + 1);
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid API token. Please check your settings.');
    }

    if (response.statusCode != 200) {
      final responseData = response.data?.toString() ?? '';
      print('❌ Details Error: ${responseData.substring(0, responseData.length > 500 ? 500 : responseData.length)}');
      throw Exception('Failed to fetch game details: ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.data.toString());
    final items = document.findAllElements('item');

    final games = <Game>[];
    for (final item in items) {
      try {
        final game = _parseGameFromXml(item);
        games.add(game);
      } catch (e) {
        print('Error parsing game: $e');
        // Continue with other games
      }
    }

    return games;
  }

  /// Parse a game from collection XML element (simpler data)
  Game _parseGameFromCollectionXml(XmlElement item) {
    final bggId = int.parse(item.getAttribute('objectid') ?? '0');

    // Get name from child element
    final nameElement = item.findElements('name').firstOrNull;
    final name = nameElement?.innerText ?? 'Unknown';

    // Get year published
    final yearElement = item.findElements('yearpublished').firstOrNull;
    final yearPublished = yearElement != null
        ? int.tryParse(yearElement.innerText)
        : null;

    // Get thumbnail
    final thumbnailElement = item.findElements('thumbnail').firstOrNull;
    final thumbnailUrl = thumbnailElement?.innerText;

    // Get image
    final imageElement = item.findElements('image').firstOrNull;
    final imageUrl = imageElement?.innerText;

    return Game(
      bggId: bggId,
      name: name,
      thumbnailUrl: thumbnailUrl,
      imageUrl: imageUrl,
      yearPublished: yearPublished,
      lastSynced: DateTime.now(),
    );
  }

  /// Parse a game from thing XML element (detailed data)
  Game _parseGameFromXml(XmlElement item) {
    final bggId = int.parse(item.getAttribute('id') ?? '0');

    // Get primary name
    final names = item.findElements('name');
    final primaryName = names
        .firstWhere(
          (name) => name.getAttribute('type') == 'primary',
          orElse: () => names.first,
        )
        .getAttribute('value') ?? 'Unknown';

    // Get description
    final descriptionElement = item.findElements('description').firstOrNull;
    final description = descriptionElement?.innerText;

    // Get images
    final imageElement = item.findElements('image').firstOrNull;
    final imageUrl = imageElement?.innerText;

    final thumbnailElement = item.findElements('thumbnail').firstOrNull;
    final thumbnailUrl = thumbnailElement?.innerText;

    // Get year published
    final yearElement = item.findElements('yearpublished').firstOrNull;
    final yearPublished = yearElement != null
        ? int.tryParse(yearElement.getAttribute('value') ?? '')
        : null;

    // Get player count
    final minPlayersElement = item.findElements('minplayers').firstOrNull;
    final minPlayers = minPlayersElement != null
        ? int.tryParse(minPlayersElement.getAttribute('value') ?? '')
        : null;

    final maxPlayersElement = item.findElements('maxplayers').firstOrNull;
    final maxPlayers = maxPlayersElement != null
        ? int.tryParse(maxPlayersElement.getAttribute('value') ?? '')
        : null;

    // Get playtime
    final minPlaytimeElement = item.findElements('minplaytime').firstOrNull;
    final minPlaytime = minPlaytimeElement != null
        ? int.tryParse(minPlaytimeElement.getAttribute('value') ?? '')
        : null;

    final maxPlaytimeElement = item.findElements('maxplaytime').firstOrNull;
    final maxPlaytime = maxPlaytimeElement != null
        ? int.tryParse(maxPlaytimeElement.getAttribute('value') ?? '')
        : null;

    // Get average rating from statistics
    double? averageRating;
    final statistics = item.findElements('statistics').firstOrNull;
    if (statistics != null) {
      final ratings = statistics.findElements('ratings').firstOrNull;
      if (ratings != null) {
        final averageElement = ratings.findElements('average').firstOrNull;
        if (averageElement != null) {
          averageRating = double.tryParse(
            averageElement.getAttribute('value') ?? '',
          );
        }
      }
    }

    // Get categories
    final categoryLinks = item.findElements('link')
        .where((link) => link.getAttribute('type') == 'boardgamecategory');
    final categories = categoryLinks
        .map((link) => link.getAttribute('value'))
        .whereType<String>()
        .toList();

    // Get mechanics
    final mechanicLinks = item.findElements('link')
        .where((link) => link.getAttribute('type') == 'boardgamemechanic');
    final mechanics = mechanicLinks
        .map((link) => link.getAttribute('value'))
        .whereType<String>()
        .toList();

    // Get expansions
    final expansionLinks = item.findElements('link')
        .where((link) => link.getAttribute('type') == 'boardgameexpansion');

    ExpansionReference? baseGame;
    List<ExpansionReference>? expansions;

    for (final link in expansionLinks) {
      final isInbound = link.getAttribute('inbound') == 'true';
      final expansionId = int.tryParse(link.getAttribute('id') ?? '');
      final expansionName = link.getAttribute('value');

      if (expansionId != null && expansionName != null) {
        if (isInbound) {
          // This game is an expansion of the linked game
          baseGame = ExpansionReference(bggId: expansionId, name: expansionName);
        } else {
          // The linked game is an expansion of this game
          expansions ??= [];
          expansions.add(ExpansionReference(bggId: expansionId, name: expansionName));
        }
      }
    }

    return Game(
      bggId: bggId,
      name: primaryName,
      description: description,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      yearPublished: yearPublished,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      minPlaytime: minPlaytime,
      maxPlaytime: maxPlaytime,
      averageRating: averageRating,
      categories: categories.isNotEmpty ? categories : null,
      mechanics: mechanics.isNotEmpty ? mechanics : null,
      baseGame: baseGame,
      expansions: expansions,
      lastSynced: DateTime.now(),
    );
  }

  /// Search for games on BGG by name
  /// Returns a list of search results with BGG ID and name
  Future<List<Map<String, dynamic>>> searchGames(String query) async {
    if (query.isEmpty) return [];

    final searchUrl = '$_baseUrl/search?query=${Uri.encodeComponent(query)}&type=boardgame,boardgameexpansion';

    print('🔍 BGG Search Request: $searchUrl');
    print('🔍 Using bearer token: ${_bearerToken != null}');

    // Create headers with bearer token if available
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/xml',
    };

    // Add bearer token if available
    if (_bearerToken != null) {
      headers['Authorization'] = 'Bearer $_bearerToken';
    }

    final cleanDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: headers,
    ));

    final response = await cleanDio.get(
      searchUrl,
      options: Options(
        validateStatus: (status) => status! < 500,
      ),
    );

    print('📡 Search Response Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to search games: ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.data.toString());
    final items = document.findAllElements('item');

    final results = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = int.tryParse(item.getAttribute('id') ?? '');
      final nameElement = item.findElements('name').firstOrNull;
      final name = nameElement?.getAttribute('value');
      final yearElement = item.findElements('yearpublished').firstOrNull;
      final year = yearElement?.getAttribute('value');

      if (id != null && name != null) {
        results.add({
          'id': id,
          'name': name,
          'year': year != null ? int.tryParse(year) : null,
        });
      }
    }

    print('✅ Found ${results.length} search results');
    return results;
  }

  /// Fetch detailed information for a single game by BGG ID
  /// Uses bearer token for authentication
  Future<Game> fetchGameDetails(int bggId) async {
    if (!hasToken) {
      throw Exception('Please set your BGG API token in settings');
    }

    final games = await _fetchGameDetails([bggId.toString()]);
    if (games.isEmpty) {
      throw Exception('Game not found with ID: $bggId');
    }
    return games.first;
  }
}
