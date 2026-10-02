/// Summary of current BoardGameGeek Marketplace asking prices for a game.
///
/// These are prices from *active* listings (what sellers are asking), not
/// completed-sale prices — BGG does not expose sold history through this API.
/// All prices are normalized to USD via the marketplace query.
class MarketValue {
  final double low; // Cheapest active listing
  final double mid; // Median asking price
  final double high; // Most expensive active listing
  final int count; // Number of listings the summary is based on
  final String currency; // Always 'USD' for now
  final DateTime syncedAt;

  MarketValue({
    required this.low,
    required this.mid,
    required this.high,
    required this.count,
    this.currency = 'USD',
    required this.syncedAt,
  });

  /// Builds a summary from a list of prices. Returns a zero-count value when
  /// [prices] is empty (i.e. no active listings).
  factory MarketValue.fromPrices(List<double> prices, {DateTime? syncedAt}) {
    final at = syncedAt ?? DateTime.now();
    if (prices.isEmpty) {
      return MarketValue(
        low: 0,
        mid: 0,
        high: 0,
        count: 0,
        syncedAt: at,
      );
    }
    final sorted = List<double>.from(prices)..sort();
    final n = sorted.length;
    final double median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    return MarketValue(
      low: sorted.first,
      mid: median,
      high: sorted.last,
      count: n,
      syncedAt: at,
    );
  }

  bool get hasListings => count > 0;
}
