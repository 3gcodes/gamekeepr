import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/market_value.dart';
import 'service_providers.dart';
import 'games_provider.dart';

/// How long a cached market value is considered fresh before we refetch.
const Duration _marketValueTtl = Duration(hours: 24);

/// Per-game market value, keyed by BGG id. Seeds from the cached values stored
/// on the game row when they are still fresh, otherwise fetches from BGG.
final marketValueProvider = StateNotifierProvider.family<MarketValueNotifier,
    AsyncValue<MarketValue?>, int>((ref, bggId) {
  return MarketValueNotifier(ref, bggId);
});

class MarketValueNotifier extends StateNotifier<AsyncValue<MarketValue?>> {
  final Ref ref;
  final int bggId;

  MarketValueNotifier(this.ref, this.bggId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  /// Loads cached value if fresh, otherwise fetches from the network.
  Future<void> _load() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final game = await db.getGameByBggId(bggId);

      if (game?.marketValueSynced != null &&
          game!.marketValueCount != null &&
          DateTime.now().difference(game.marketValueSynced!) <
              _marketValueTtl) {
        state = AsyncValue.data(MarketValue(
          low: game.marketValueLow ?? 0,
          mid: game.marketValueMid ?? 0,
          high: game.marketValueHigh ?? 0,
          count: game.marketValueCount!,
          syncedAt: game.marketValueSynced!,
        ));
        return;
      }

      await _fetch();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Forces a fresh fetch from BGG, ignoring the cache.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final marketService = ref.read(marketServiceProvider);
      final db = ref.read(databaseServiceProvider);

      final value = await marketService.fetchMarketValue(bggId);

      // Persist against the local game row, if we have one.
      final game = await db.getGameByBggId(bggId);
      if (game?.id != null) {
        await db.updateGameMarketValue(game!.id!, value);
        // Refresh the collection list so cached values stay in sync.
        ref.read(gamesProvider.notifier).loadGames();
      }

      state = AsyncValue.data(value);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
