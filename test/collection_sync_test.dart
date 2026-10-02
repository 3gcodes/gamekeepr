import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamekeepr/models/game.dart';
import 'package:gamekeepr/providers/app_providers.dart';
import 'package:gamekeepr/services/bgg_service.dart';
import 'package:gamekeepr/services/database_service.dart';

class _FakeDatabaseService extends Fake implements DatabaseService {
  final Map<int, Game> games = {};
  int _nextId = 1;

  @override
  Future<List<Game>> getAllGames({String? orderBy}) async =>
      games.values.toList();

  @override
  Future<Game?> getGameByBggId(int bggId) async {
    for (final game in games.values) {
      if (game.bggId == bggId) return game;
    }
    return null;
  }

  @override
  Future<Game> insertGame(Game game) async {
    final saved = game.copyWith(id: _nextId++);
    games[saved.id!] = saved;
    return saved;
  }

  @override
  Future<int> updateGame(Game game) async {
    games[game.id!] = game;
    return 1;
  }
}

class _FakeBggService extends Fake implements BggService {
  List<Game> collection = [];
  Map<int, Game> details = {};
  Set<int> failingIds = {};
  final List<List<int>> detailRequests = [];

  @override
  void setBearerToken(String token) {}

  @override
  Future<List<Game>> fetchCollection(String username,
          {int retryCount = 0}) async =>
      collection;

  @override
  Stream<List<Game>> fetchGamesDetails(List<int> bggIds) async* {
    detailRequests.add(bggIds);
    for (final id in bggIds) {
      if (failingIds.contains(id)) throw Exception('BGG is down');
      yield [details[id]!];
    }
  }
}

// What the collection endpoint knows about a game
Game _collectionGame(int bggId, String name) =>
    Game(bggId: bggId, name: name, thumbnailUrl: 'thumb-$bggId');

// What the thing endpoint knows about a game
Game _detailedGame(int bggId, String name, {required int maxPlayers}) => Game(
      bggId: bggId,
      name: name,
      description: 'About $name',
      minPlayers: 1,
      maxPlayers: maxPlayers,
      categories: ['Category $bggId'],
      mechanics: ['Mechanic $bggId'],
      owned: false,
      lastSynced: DateTime(2026, 10, 1),
    );

void main() {
  late _FakeDatabaseService db;
  late _FakeBggService bgg;
  late ProviderContainer container;

  setUp(() {
    db = _FakeDatabaseService();
    bgg = _FakeBggService();
    container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(db),
      bggServiceProvider.overrideWithValue(bgg),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> sync() =>
      container.read(gamesProvider.notifier).syncFromBgg('user', 'token');

  test('merging BGG details keeps data stored locally', () {
    final stored = Game(
      id: 7,
      bggId: 10,
      name: 'Patchwork',
      location: 'B8',
      owned: true,
      wishlisted: true,
      hasNfcTag: true,
      marketValueMid: 25,
    );

    final merged = stored.withDetails(
      _detailedGame(10, 'Patchwork', maxPlayers: 2),
    );

    expect(merged.maxPlayers, 2);
    expect(merged.categories, ['Category 10']);
    expect(merged.lastSynced, DateTime(2026, 10, 1));
    expect(merged.id, 7);
    expect(merged.location, 'B8');
    expect(merged.owned, isTrue);
    expect(merged.wishlisted, isTrue);
    expect(merged.hasNfcTag, isTrue);
    expect(merged.marketValueMid, 25);
  });

  test('sync stores player counts, categories and mechanics for new games',
      () async {
    bgg.collection = [_collectionGame(10, 'Patchwork')];
    bgg.details = {10: _detailedGame(10, 'Patchwork', maxPlayers: 2)};

    await sync();

    final game = db.games.values.single;
    expect(game.owned, isTrue);
    expect(game.thumbnailUrl, 'thumb-10');
    expect(game.maxPlayers, 2);
    expect(game.categories, ['Category 10']);
    expect(game.mechanics, ['Mechanic 10']);

    // The filter now finds it
    container.read(maxPlayersFilterProvider.notifier).state = 2;
    final filtered = container.read(filteredGamesProvider).value!;
    expect(filtered.map((game) => game.name), ['Patchwork']);
  });

  test('sync keeps stored details and local data for existing games',
      () async {
    await db.insertGame(
      _detailedGame(10, 'Patchwork', maxPlayers: 2).copyWith(
        owned: true,
        location: 'B8',
        hasNfcTag: true,
        marketValueMid: 25,
      ),
    );
    bgg.collection = [_collectionGame(10, 'Patchwork')];

    await sync();

    final game = db.games.values.single;
    expect(game.maxPlayers, 2);
    expect(game.categories, ['Category 10']);
    expect(game.location, 'B8');
    expect(game.hasNfcTag, isTrue);
    expect(game.marketValueMid, 25);
    // Details were already stored, so nothing was fetched again
    expect(bgg.detailRequests, isEmpty);
  });

  test('sync backfills details for existing games that lack them', () async {
    await db.insertGame(
      _collectionGame(10, 'Patchwork').copyWith(location: 'B8'),
    );
    await db.insertGame(
      _detailedGame(11, 'Catan', maxPlayers: 4).copyWith(owned: true),
    );
    bgg.collection = [
      _collectionGame(10, 'Patchwork'),
      _collectionGame(11, 'Catan'),
    ];
    bgg.details = {10: _detailedGame(10, 'Patchwork', maxPlayers: 2)};

    await sync();

    expect(bgg.detailRequests, [
      [10],
    ]);
    final patchwork = await db.getGameByBggId(10);
    expect(patchwork!.maxPlayers, 2);
    expect(patchwork.location, 'B8');
    expect(patchwork.owned, isTrue);
  });

  test('a failed details fetch keeps the collection and earlier details',
      () async {
    bgg.collection = [
      _collectionGame(10, 'Patchwork'),
      _collectionGame(11, 'Catan'),
    ];
    bgg.details = {10: _detailedGame(10, 'Patchwork', maxPlayers: 2)};
    bgg.failingIds = {11};

    await expectLater(sync(), throwsException);

    final games = container.read(gamesProvider).value!;
    expect(games.map((game) => game.name), ['Patchwork', 'Catan']);
    expect(games.first.maxPlayers, 2);
    expect(games.last.maxPlayers, isNull);
  });
}
