import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamekeepr/screens/start_player_screen.dart';

/// Always picks the same index so the chosen touch is predictable.
class _FixedRandom implements Random {
  _FixedRandom(this.index);

  final int index;

  @override
  int nextInt(int max) => index;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

const _hint = 'Everyone touch and hold the screen';

// The countdown completes on the first frame after 3 seconds have elapsed
const _countdown = Duration(milliseconds: 3100);

Finder _circle(int pointer) => find.byKey(ValueKey<int>(pointer));

Future<void> _pumpScreen(WidgetTester tester, {Random? random}) {
  return tester.pumpWidget(
    MaterialApp(home: StartPlayerScreen(random: random)),
  );
}

void main() {
  testWidgets('shows a circle under each held touch', (tester) async {
    await _pumpScreen(tester);
    expect(find.text(_hint), findsOneWidget);

    final first = await tester.startGesture(const Offset(200, 200), pointer: 1);
    final second = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await tester.pump();

    expect(find.text(_hint), findsNothing);
    expect(tester.getCenter(_circle(1)), const Offset(200, 200));
    expect(tester.getCenter(_circle(2)), const Offset(500, 400));

    await first.up();
    await second.up();
    await tester.pump();
  });

  testWidgets('circle follows a dragged touch', (tester) async {
    await _pumpScreen(tester);

    final gesture = await tester.startGesture(const Offset(200, 200), pointer: 1);
    await tester.pump();
    await gesture.moveTo(const Offset(350, 420));
    await tester.pump();

    expect(tester.getCenter(_circle(1)), const Offset(350, 420));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('keeps only the chosen touch after 3 seconds', (tester) async {
    await _pumpScreen(tester, random: _FixedRandom(1));

    final first = await tester.startGesture(const Offset(200, 200), pointer: 1);
    final second = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2900));
    expect(_circle(1), findsOneWidget);
    expect(_circle(2), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(_circle(1), findsNothing);
    expect(_circle(2), findsOneWidget);

    // The chosen circle still follows its finger
    await second.moveTo(const Offset(450, 300));
    await tester.pumpAndSettle();
    expect(tester.getCenter(_circle(2)), const Offset(450, 300));

    await first.up();
    await second.up();
    await tester.pump();
  });

  testWidgets('a single touch shows a circle but never starts the timer',
      (tester) async {
    await _pumpScreen(tester);

    final first = await tester.startGesture(const Offset(200, 200), pointer: 1);
    await tester.pump();
    await tester.pump(_countdown);
    expect(_circle(1), findsOneWidget);

    // No pick has happened, so a second touch still joins the round
    final second = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await tester.pump();
    expect(_circle(1), findsOneWidget);
    expect(_circle(2), findsOneWidget);

    await tester.pump(_countdown);
    expect(_circle(1).evaluate().length + _circle(2).evaluate().length, 1);

    await first.up();
    await second.up();
    await tester.pump();
  });

  testWidgets('dropping to a single touch stops the timer', (tester) async {
    await _pumpScreen(tester);

    final first = await tester.startGesture(const Offset(200, 200), pointer: 1);
    final second = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await second.up();
    await tester.pump();
    await tester.pump(_countdown);

    // Still no pick, so a new touch joins the round
    final third = await tester.startGesture(const Offset(500, 400), pointer: 3);
    await tester.pump();
    expect(_circle(1), findsOneWidget);
    expect(_circle(3), findsOneWidget);

    await first.up();
    await third.up();
    await tester.pump();
  });

  testWidgets('a new touch restarts the timer', (tester) async {
    await _pumpScreen(tester);

    final first = await tester.startGesture(const Offset(200, 200), pointer: 1);
    final second = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final third = await tester.startGesture(const Offset(350, 500), pointer: 3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // 4 seconds since the timer first started, but only 2 since the third touch
    expect(_circle(1), findsOneWidget);
    expect(_circle(2), findsOneWidget);
    expect(_circle(3), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    final remaining = [1, 2, 3].where((p) => _circle(p).evaluate().isNotEmpty);
    expect(remaining, hasLength(1));

    await first.up();
    await second.up();
    await third.up();
    await tester.pump();
  });

  testWidgets('touches after the pick are ignored', (tester) async {
    await _pumpScreen(tester, random: _FixedRandom(0));

    final first = await tester.startGesture(const Offset(200, 200), pointer: 1);
    final second = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await tester.pump();
    await tester.pump(_countdown);

    final late = await tester.startGesture(const Offset(350, 500), pointer: 3);
    await tester.pump();

    expect(_circle(1), findsOneWidget);
    expect(_circle(2), findsNothing);
    expect(_circle(3), findsNothing);

    await first.up();
    await second.up();
    await late.up();
    await tester.pump();
  });

  testWidgets('removing all touches resets the process', (tester) async {
    await _pumpScreen(tester, random: _FixedRandom(0));

    final first = await tester.startGesture(const Offset(200, 200), pointer: 1);
    final second = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await tester.pump();
    await tester.pump(_countdown);
    expect(_circle(1), findsOneWidget);
    expect(_circle(2), findsNothing);

    // The chosen circle stays until the last finger is lifted
    await first.up();
    await tester.pump();
    expect(_circle(1), findsOneWidget);

    await second.up();
    await tester.pump();
    expect(_circle(1), findsNothing);
    expect(find.text(_hint), findsOneWidget);

    // A fresh round works after the reset
    final third = await tester.startGesture(const Offset(300, 300), pointer: 3);
    final fourth = await tester.startGesture(const Offset(450, 450), pointer: 4);
    await tester.pump();
    expect(_circle(3), findsOneWidget);
    expect(_circle(4), findsOneWidget);
    await tester.pump(_countdown);
    expect(_circle(3), findsOneWidget);
    expect(_circle(4), findsNothing);

    await third.up();
    await fourth.up();
    await tester.pump();
    expect(find.text(_hint), findsOneWidget);
  });
}
