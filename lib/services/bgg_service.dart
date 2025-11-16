import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:xml/xml.dart';
import '../models/game.dart';

class BggService {
  static const String _baseUrl = 'https://boardgamegeek.com/xmlapi2';
  static const String _loginUrl = 'https://boardgamegeek.com/login/api/v1';

  final CookieJar _cookieJar = CookieJar();
  late final Dio _dio = _createDio();
  bool _isAuthenticated = false;

  // Store credentials for auto-relogin
  String? _storedUsername;
  String? _storedPassword;

  Dio _createDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ));

    // Use Dio's built-in cookie manager
    dio.interceptors.add(CookieManager(_cookieJar));

    // Add logging interceptor to debug cookie issues
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies = await _cookieJar.loadForRequest(options.uri);
        print('🍪 Cookies for ${options.uri}: ${cookies.map((c) => '${c.name}=${c.value}').join('; ')}');
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        final setCookies = response.headers['set-cookie'];
        if (setCookies != null) {
          print('🍪 Set-Cookie received: $setCookies');
        }
        return handler.next(response);
      },
    ));

    return dio;
  }

  /// Login to BGG with username and password
  Future<bool> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required');
    }

    try {
      print('🔐 Attempting BGG login for user: $username');

      // BGG uses the web login endpoint with JSON credentials
      final response = await _dio.post(
        _loginUrl,
        data: {
          'credentials': {
            'username': username,
            'password': password,
          }
        },
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (status) => status! < 500,
          followRedirects: true,
        ),
      );

      print('🔐 Login response status: ${response.statusCode}');
      print('🔐 Login response data: ${response.data}');

      // Check if login was successful (200, 202, or 204 are all success)
      if (response.statusCode == 200 || response.statusCode == 202 || response.statusCode == 204) {
        // Check if response has error (only if there's data)
        if (response.data is Map && response.data['errors'] != null) {
          print('❌ Login failed: ${response.data['errors']}');
          _isAuthenticated = false;
          return false;
        }

        _isAuthenticated = true;
        // Store credentials for auto-relogin
        _storedUsername = username;
        _storedPassword = password;
        print('✅ Successfully logged in to BGG');
        return true;
      } else {
        print('❌ Login failed with status ${response.statusCode}');
        _isAuthenticated = false;
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Fetch collection for a given username
  Future<List<Game>> fetchCollection(String username, {int retryCount = 0}) async {
    if (username.isEmpty) {
      throw Exception('Username cannot be empty');
    }

    if (!_isAuthenticated) {
      throw Exception('Please login to BGG first');
    }

    // Request collection
    final collectionUrl = '$_baseUrl/collection?username=$username&own=1';

    print('🔍 BGG API Request: $collectionUrl');
    print('🔍 Retry count: $retryCount');

    final response = await _dio.get(
      collectionUrl,
      options: Options(
        validateStatus: (status) => status! < 500,
      ),
    );

    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Headers: ${response.headers}');

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
      _isAuthenticated = false;
      throw Exception('Authentication expired. Please login again.');
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
  /// This is a PUBLIC endpoint - create new Dio instance without cookies
  Future<List<Game>> _fetchGameDetails(List<String?> gameIds, {int retryCount = 0}) async {
    if (gameIds.isEmpty) return [];

    // BGG API allows multiple IDs separated by commas
    final idsString = gameIds.join(',');
    final detailsUrl = '$_baseUrl/thing?id=$idsString&stats=1';

    print('🔍 BGG API Details Request: $detailsUrl (no auth)');

    // Create a clean Dio instance WITHOUT any cookies or auth
    final cleanDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/xml',
      },
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
      _isAuthenticated = false;
      throw Exception('Authentication expired. Please login again.');
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
      lastSynced: DateTime.now(),
    );
  }

  /// Fetch detailed information for a single game by BGG ID
  /// Requires authentication and will auto-retry with re-login on 401
  Future<Game> fetchGameDetails(int bggId, {bool isRetry = false}) async {
    if (!_isAuthenticated && !isRetry) {
      // Try auto-relogin if we have stored credentials
      if (_storedUsername != null && _storedPassword != null) {
        print('🔄 Not authenticated, attempting auto-relogin...');
        final loginSuccess = await login(_storedUsername!, _storedPassword!);
        if (!loginSuccess) {
          throw Exception('Please login to BGG first');
        }
        return fetchGameDetails(bggId, isRetry: true);
      }
      throw Exception('Please login to BGG first');
    }

    try {
      final games = await _fetchGameDetails([bggId.toString()]);
      if (games.isEmpty) {
        throw Exception('Game not found with ID: $bggId');
      }
      return games.first;
    } catch (e) {
      // If we get a 401 error and haven't retried yet, try to re-login
      if (e.toString().contains('Authentication expired') && !isRetry) {
        if (_storedUsername != null && _storedPassword != null) {
          print('🔄 Session expired, attempting auto-relogin...');
          final loginSuccess = await login(_storedUsername!, _storedPassword!);
          if (loginSuccess) {
            print('✅ Auto-relogin successful, retrying fetch...');
            return fetchGameDetails(bggId, isRetry: true);
          }
        }
      }
      rethrow;
    }
  }
}
