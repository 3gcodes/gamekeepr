import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xml/xml.dart';
import '../models/game.dart';

class BggService {
  static const String _baseUrl = 'https://boardgamegeek.com/xmlapi2';
  static const String _webBaseUrl = 'https://boardgamegeek.com';

  // Store bearer token for API v2 authenticated requests
  String? _bearerToken;

  // Cookie jar for maintaining web login session
  final CookieJar _cookieJar = CookieJar();
  late final Dio _webDio;
  bool _isLoggedIn = false;

  BggService() {
    // Initialize web Dio instance with cookie manager for form-based auth
    _webDio = Dio(BaseOptions(
      baseUrl: _webBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ));
    _webDio.interceptors.add(CookieManager(_cookieJar));
  }

  /// Set bearer token for API v2 authenticated requests
  void setBearerToken(String token) {
    _bearerToken = token;
  }

  /// Check if bearer token is set
  bool get hasToken => _bearerToken != null && _bearerToken!.isNotEmpty;

  /// Check if user is logged in via web session
  bool get isLoggedIn => _isLoggedIn;

  /// Login to BGG using username and password to establish a session
  Future<void> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      throw Exception('Username and password cannot be empty');
    }

    try {
      print('🔐 Attempting BGG login for user: $username');

      // BGG login endpoint
      const loginUrl = '/login/api/v1';

      // Prepare form data
      final formData = FormData.fromMap({
        'credentials': {
          'username': username,
          'password': password,
        },
      });

      final response = await _webDio.post(
        loginUrl,
        data: formData,
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (status) => status! < 500,
        ),
      );

      print('📡 Login Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        _isLoggedIn = true;
        print('✅ Successfully logged in to BGG');
      } else {
        _isLoggedIn = false;
        throw Exception('Login failed with status ${response.statusCode}. Please check your credentials.');
      }
    } catch (e) {
      _isLoggedIn = false;
      print('❌ Login error: $e');
      rethrow;
    }
  }

  /// Update game ownership status in BGG collection
  Future<void> updateGameOwnership(int bggId, bool owned, {String? gameName, String? imageUrl, String? thumbnailUrl}) async {
    if (!_isLoggedIn) {
      throw Exception('Must be logged in to update collection. Please check your BGG password in settings.');
    }

    try {
      print('🔄 Updating BGG collection for game $bggId, owned: $owned');

      // First, try to GET the collection item to see if it exists and get its collid
      print('📥 Checking if item exists in collection...');
      final getResponse = await _webDio.get(
        '/api/collectionitems/$bggId',
        options: Options(
          validateStatus: (status) => status! < 500,
        ),
      );

      print('📡 GET Response Status: ${getResponse.statusCode}');

      Response response;

      if (getResponse.statusCode == 200) {
        // Item exists, use PUT to update it
        print('✅ Item exists in collection, updating...');
        final existingItem = getResponse.data;
        print('📦 Existing item data: $existingItem');

        // Prepare PUT payload with the existing item data
        final putPayload = {
          ...existingItem, // Keep all existing fields
          'status': {
            ...((existingItem['status'] as Map?) ?? {}),
            'own': owned,
          },
        };

        print('📦 PUT Payload (merged): ${putPayload.keys.toList()}');

        response = await _webDio.put(
          '/api/collectionitems/$bggId',
          data: putPayload,
          options: Options(
            contentType: Headers.jsonContentType,
            validateStatus: (status) => status! < 500,
          ),
        );

        print('📡 PUT Response Status: ${response.statusCode}');
        print('📡 PUT Response Headers: ${response.headers}');
        print('📡 PUT Response Body: ${response.data}');
      } else {
        // Item doesn't exist in BGG collection
        if (!owned) {
          // User is removing ownership of a game not in BGG collection
          // This is a no-op - item already doesn't exist
          print('✅ Item already not in BGG collection, nothing to do');
          return;
        }

        // Item doesn't exist, try using geekplay.php (legacy endpoint)
        print('📤 Item not in collection, attempting POST to /geekplay.php');

        // Try form-encoded data - use collid instead of action
        final formData = {
          'ajax': '1',
          'collid': 'new',
          'objecttype': 'thing',
          'objectid': bggId.toString(),
          'own': '1',
        };

        print('📦 Form Data: $formData');

        response = await _webDio.post(
          '/geekplay.php',
          data: formData,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            validateStatus: (status) => status! < 500,
          ),
        );

        print('📡 POST Response Status: ${response.statusCode}');
        print('📡 POST Response Headers: ${response.headers}');
        print('📡 POST Response Body: ${response.data}');
      }

      // Check for success (200/201/204) but also verify no HTML error messages
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        final responseBody = response.data;

        // Check for HTML error messages even in 200 responses
        if (responseBody is String && (responseBody.contains('messagebox error') || responseBody.contains('Invalid'))) {
          print('❌ Error: Received HTML error message despite 200 status');
          print('❌ Response body: $responseBody');
          throw Exception('BGG API error: ${responseBody.contains('Invalid action') ? 'Invalid action' : 'Unknown error'}');
        }

        print('✅ Successfully updated BGG collection for game $bggId');
      } else {
        final errorMessage = 'Failed to update collection: ${response.statusCode}';
        final responseBody = response.data;
        print('❌ Error: $errorMessage');
        print('❌ Response body: $responseBody');

        // Try to extract error details from response
        String detailMessage = errorMessage;
        if (responseBody is Map && responseBody.containsKey('title')) {
          detailMessage = '$errorMessage - ${responseBody['title']}';
          if (responseBody.containsKey('detail')) {
            detailMessage += ': ${responseBody['detail']}';
          }
        }

        throw Exception(detailMessage);
      }
    } catch (e) {
      print('❌ Collection update error: $e');
      rethrow;
    }
  }

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
      owned: false, // Games fetched from BGG details are not owned by default
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

  /// Fetch play data for a game from BGG
  /// Returns a list of play dates with win/loss information
  Future<List<Map<String, dynamic>>> fetchPlaysForGame(String username, int bggId) async {
    if (username.isEmpty) {
      throw Exception('Username cannot be empty');
    }

    if (!hasToken) {
      throw Exception('Please set your BGG API token in settings');
    }

    final playsUrl = '$_baseUrl/plays?username=$username&id=$bggId&page=1';

    print('🔍 BGG Plays Request: $playsUrl');

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
      playsUrl,
      options: Options(
        validateStatus: (status) => status! < 500,
      ),
    );

    print('📡 Plays Response Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch plays: ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.data.toString());
    final playElements = document.findAllElements('play');

    final plays = <Map<String, dynamic>>[];
    for (final playElement in playElements) {
      try {
        final dateStr = playElement.getAttribute('date');
        if (dateStr == null || dateStr.isEmpty) continue;

        final datePlayed = DateTime.parse(dateStr);

        // Check for win/loss in players section
        bool? won;
        final playersElement = playElement.findElements('players').firstOrNull;
        if (playersElement != null) {
          final playerElements = playersElement.findElements('player');
          // Look for the current user's player entry
          for (final player in playerElements) {
            final playerUsername = player.getAttribute('username');
            if (playerUsername?.toLowerCase() == username.toLowerCase()) {
              final winAttr = player.getAttribute('win');
              if (winAttr != null && winAttr.isNotEmpty) {
                won = winAttr == '1';
              }
              break;
            }
          }
        }

        plays.add({
          'datePlayed': datePlayed,
          'won': won,
        });
      } catch (e) {
        print('Error parsing play: $e');
        // Continue with other plays
      }
    }

    print('✅ Parsed ${plays.length} plays from BGG');
    return plays;
  }
}
