import 'package:dio/dio.dart';
import '../models/market_value.dart';

/// Fetches current BoardGameGeek Marketplace listings for a game and summarizes
/// them into low / median / high asking prices.
///
/// Notes learned from the (unofficial) endpoint:
/// - Base URL is `https://api.geekdo.com/api/market/products`.
/// - Only ONE object can be queried per request; comma-separated ids return
///   only the first, so callers must fetch one game at a time.
/// - `currency=USD&country=US` returns every listing already priced in USD.
/// - `config.numitems` is the total count; results paginate 50 per page.
class MarketService {
  static const String _baseUrl =
      'https://api.geekdo.com/api/market/products';

  /// Safety cap so a game with hundreds of listings doesn't fan out forever.
  static const int _maxListings = 200;
  static const int _itemsPerPage = 50;

  final Dio _dio;

  MarketService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ));

  /// Fetches all active USD listings for [bggId] and returns a summary.
  /// Returns a zero-count [MarketValue] when there are no active listings.
  Future<MarketValue> fetchMarketValue(int bggId) async {
    final prices = <double>[];
    int page = 1;
    int? totalItems;

    while (prices.length < _maxListings) {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'ajax': 1,
          'objecttype': 'thing',
          'marketdomain': 'boardgame',
          'productstate': 'active',
          'stock': 'instock',
          'currency': 'USD',
          'country': 'US',
          'condition': 'any',
          'sort': 'recent',
          'objectid': bggId,
          'pageid': page,
        },
      );

      final data = response.data;
      if (data is! Map) break;

      totalItems ??= _asInt(data['config']?['numitems']) ?? 0;

      final products = data['products'];
      if (products is! List || products.isEmpty) break;

      for (final p in products) {
        final price = _asDouble((p as Map)['price']);
        if (price != null && price > 0) prices.add(price);
      }

      // Stop once we've seen every listing or a short/empty page.
      if (products.length < _itemsPerPage) break;
      if (prices.length >= totalItems) break;
      page++;
    }

    return MarketValue.fromPrices(prices);
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
