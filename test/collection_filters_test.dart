import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamekeepr/models/game.dart';
import 'package:gamekeepr/providers/app_providers.dart';
import 'package:gamekeepr/screens/bgg_search_screen.dart';
import 'package:gamekeepr/screens/games_tab_screen.dart';

final _games = [
  Game(
    id: 1,
    bggId: 1,
    name: 'Catan',
    maxPlayers: 4,
    categories: ['Economic', 'Negotiation'],
    mechanics: ['Dice Rolling', 'Trading'],
  ),
  Game(
    id: 2,
    bggId: 2,
    name: 'Codenames',
    maxPlayers: 8,
    categories: ['Party Game', 'Word Game'],
    mechanics: ['Team-Based Game'],
  ),
  Game(
    id: 3,
    bggId: 3,
    name: 'Camel Up',
    maxPlayers: 8,
    categories: ['Party Game', 'Racing'],
    mechanics: ['Betting and Bluffing', 'Dice Rolling'],
  ),
  Game(
    id: 6,
    bggId: 6,
    name: 'Patchwork',
    maxPlayers: 2,
    categories: ['Abstract Strategy', 'Economic'],
    mechanics: ['Tile Placement'],
  ),
  // Synced without details, so nothing to filter on
  Game(id: 4, bggId: 4, name: 'Mystery Game'),
  // Not owned, so never part of the collection
  Game(
    id: 5,
    bggId: 5,
    name: 'Wavelength',
    maxPlayers: 12,
    categories: ['Party Game'],
    mechanics: ['Team-Based Game'],
    owned: false,
  ),
];

class _FakeGamesNotifier extends GamesNotifier {
  _FakeGamesNotifier(super.ref);

  @override
  Future<void> loadGames() async {
    state = AsyncValue.data(_games);
  }
}

final _overrides = [
  gamesProvider.overrideWith((ref) => _FakeGamesNotifier(ref)),
  gameTagsMapProvider.overrideWith((ref) async => <int, List<String>>{}),
];

void main() {
  group('filteredGamesProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: _overrides);
      addTearDown(container.dispose);
    });

    List<String> names() => container
        .read(filteredGamesProvider)
        .value!
        .map((game) => game.name)
        .toList();

    test('shows all owned games when no filters are set', () {
      expect(
        names(),
        ['Catan', 'Codenames', 'Camel Up', 'Patchwork', 'Mystery Game'],
      );
      expect(container.read(activeFilterCountProvider), 0);
    });

    test('filters by exact max player count, with 6 meaning 6 or more', () {
      container.read(maxPlayersFilterProvider.notifier).state = 2;
      expect(names(), ['Patchwork']);

      container.read(maxPlayersFilterProvider.notifier).state = 4;
      expect(names(), ['Catan']);

      container.read(maxPlayersFilterProvider.notifier).state = 5;
      expect(names(), isEmpty);

      container.read(maxPlayersFilterProvider.notifier).state = 6;
      expect(names(), ['Codenames', 'Camel Up']);
    });

    test('filters by categories, matching any of them', () {
      container.read(categoryFilterProvider.notifier).state = {'Racing'};
      expect(names(), ['Camel Up']);

      container.read(categoryFilterProvider.notifier).state = {
        'Racing',
        'Economic',
      };
      expect(names(), ['Catan', 'Camel Up', 'Patchwork']);
    });

    test('filters by mechanics, matching any of them', () {
      container.read(mechanicFilterProvider.notifier).state = {'Trading'};
      expect(names(), ['Catan']);

      container.read(mechanicFilterProvider.notifier).state = {
        'Trading',
        'Tile Placement',
      };
      expect(names(), ['Catan', 'Patchwork']);
    });

    test('combines all three filters with the text search', () {
      container.read(maxPlayersFilterProvider.notifier).state = 6;
      container.read(categoryFilterProvider.notifier).state = {
        'Party Game',
        'Economic',
      };
      expect(names(), ['Codenames', 'Camel Up']);

      container.read(mechanicFilterProvider.notifier).state = {
        'Dice Rolling',
        'Trading',
      };
      expect(names(), ['Camel Up']);
      expect(container.read(activeFilterCountProvider), 3);

      container.read(searchQueryProvider.notifier).state = 'camel';
      expect(names(), ['Camel Up']);

      container.read(searchQueryProvider.notifier).state = 'code';
      expect(names(), isEmpty);
    });

    test('offers the categories and mechanics of owned games', () {
      expect(container.read(collectionCategoriesProvider), [
        'Abstract Strategy',
        'Economic',
        'Negotiation',
        'Party Game',
        'Racing',
        'Word Game',
      ]);
      expect(container.read(collectionMechanicsProvider), [
        'Betting and Bluffing',
        'Dice Rolling',
        'Team-Based Game',
        'Tile Placement',
        'Trading',
      ]);
    });
  });

  group('GamesTabScreen filters', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides,
          child: const MaterialApp(home: GamesTabScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('applies filters picked in the filter sheet', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Catan'), findsOneWidget);
      expect(find.text('Codenames'), findsOneWidget);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Game Type'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '6+'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '4'));
      await tester.pumpAndSettle();

      // Pick two mechanics, using the picker's search for the first
      await tester.tap(find.widgetWithText(InputDecorator, 'Mechanics'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'dice');
      await tester.pumpAndSettle();
      expect(find.text('Trading'), findsNothing);
      await tester.tap(find.text('Dice Rolling'));
      await tester.enterText(find.byType(TextField).last, '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tile Placement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Dice Rolling, Tile Placement'), findsOneWidget);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Catan'), findsOneWidget);
      expect(find.text('Camel Up'), findsNothing);
      expect(find.text('Codenames'), findsNothing);
      // Badge shows the number of active filters
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('reset clears the filters', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InputDecorator, 'Categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Racing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Racing'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Racing'), findsNothing);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Catan'), findsOneWidget);
    });

    testWidgets('BGG search only receives the search text', (tester) async {
      await pumpScreen(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GamesTabScreen)),
      );
      container.read(categoryFilterProvider.notifier).state = {'Racing'};
      await tester.pumpAndSettle();
      expect(find.text('Camel Up'), findsOneWidget);
      expect(find.text('Search BGG'), findsNothing);

      // Catan is in the collection but hidden by the category filter
      await tester.enterText(find.byType(TextField), 'catan');
      await tester.pumpAndSettle();
      expect(find.text('No games found'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);

      await tester.tap(find.text('Search BGG'));
      await tester.pump();
      await tester.pump();
      final bggSearch = tester.widget<BggSearchScreen>(
        find.byType(BggSearchScreen),
      );
      expect(bggSearch.initialQuery, 'catan');
    });

    testWidgets('offers to clear filters when nothing matches', (tester) async {
      await pumpScreen(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GamesTabScreen)),
      );
      container.read(maxPlayersFilterProvider.notifier).state = 6;
      container.read(categoryFilterProvider.notifier).state = {'Economic'};
      await tester.pumpAndSettle();

      expect(find.text('No games match your filters'), findsOneWidget);
      expect(find.text('Search BGG'), findsNothing);

      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Catan'), findsOneWidget);
    });
  });
}
