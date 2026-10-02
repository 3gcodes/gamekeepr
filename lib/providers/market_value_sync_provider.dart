import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import 'service_providers.dart';
import 'games_provider.dart';

enum MarketValueSyncStatus { idle, running, done, error }

class MarketValueSyncState {
  final MarketValueSyncStatus status;
  final int total;
  final int completed;
  final String? currentName;
  final String? error;

  const MarketValueSyncState({
    this.status = MarketValueSyncStatus.idle,
    this.total = 0,
    this.completed = 0,
    this.currentName,
    this.error,
  });

  double get progress => total == 0 ? 0 : completed / total;

  MarketValueSyncState copyWith({
    MarketValueSyncStatus? status,
    int? total,
    int? completed,
    String? currentName,
    String? error,
  }) {
    return MarketValueSyncState(
      status: status ?? this.status,
      total: total ?? this.total,
      completed: completed ?? this.completed,
      currentName: currentName ?? this.currentName,
      error: error ?? this.error,
    );
  }
}

/// App-scoped so the collection valuation keeps running as the user navigates
/// around the app (it is registered at the root ProviderScope and never
/// disposed while work is in flight).
final marketValueSyncProvider =
    StateNotifierProvider<MarketValueSyncNotifier, MarketValueSyncState>((ref) {
  return MarketValueSyncNotifier(ref);
});

class MarketValueSyncNotifier extends StateNotifier<MarketValueSyncState> {
  final Ref ref;

  /// Number of games fetched at once. BGG only allows one game per request, so
  /// this keeps a small, polite amount of concurrency.
  static const int _concurrency = 3;

  /// Small pause between requests within a worker to be gentle on the API.
  static const Duration _delayBetween = Duration(milliseconds: 250);

  MarketValueSyncNotifier(this.ref) : super(const MarketValueSyncState());

  /// Values every owned game in the collection. Each game is persisted as soon
  /// as it completes, so an interrupted run simply resumes on the next launch.
  Future<void> startAll() async {
    if (state.status == MarketValueSyncStatus.running) return;

    final db = ref.read(databaseServiceProvider);
    final marketService = ref.read(marketServiceProvider);

    final allGames = await db.getAllGames();
    final games = allGames.where((g) => g.owned).toList();

    if (games.isEmpty) {
      state = const MarketValueSyncState(status: MarketValueSyncStatus.done);
      return;
    }

    state = MarketValueSyncState(
      status: MarketValueSyncStatus.running,
      total: games.length,
      completed: 0,
    );

    final queue = List<Game>.from(games);

    Future<void> worker() async {
      while (queue.isNotEmpty && mounted) {
        final game = queue.removeAt(0);
        state = state.copyWith(currentName: game.name);
        try {
          final value = await marketService.fetchMarketValue(game.bggId);
          if (game.id != null) {
            await db.updateGameMarketValue(game.id!, value);
          }
        } catch (_) {
          // Skip failures (network, etc.) without aborting the whole run.
        }
        if (!mounted) return;
        state = state.copyWith(completed: state.completed + 1);
        await Future.delayed(_delayBetween);
      }
    }

    try {
      await Future.wait(
        List.generate(_concurrency, (_) => worker()),
      );
      if (!mounted) return;
      state = state.copyWith(
        status: MarketValueSyncStatus.done,
        currentName: null,
      );
      // Refresh the collection list so detail screens show the new values.
      ref.read(gamesProvider.notifier).loadGames();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: MarketValueSyncStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() {
    if (state.status == MarketValueSyncStatus.running) return;
    state = const MarketValueSyncState();
  }
}
