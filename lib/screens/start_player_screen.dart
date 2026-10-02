import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StartPlayerScreen extends StatefulWidget {
  const StartPlayerScreen({super.key, this.random});

  /// Source of randomness for picking the start player. Injectable for tests.
  final Random? random;

  @override
  State<StartPlayerScreen> createState() => _StartPlayerScreenState();
}

class _StartPlayerScreenState extends State<StartPlayerScreen>
    with SingleTickerProviderStateMixin {
  static const _countdown = Duration(seconds: 3);
  static const _minTouches = 2;

  static const _touchColors = <Color>[
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.brown,
    Colors.cyan,
    Colors.lime,
  ];

  // Doubles as the 3 second timer and the progress of the countdown rings
  late final AnimationController _countdownController;
  late final Random _random;

  // Every finger currently on the screen, including ones that were not chosen
  // or arrived after the pick. The round resets once this is empty.
  final Set<int> _activePointers = {};

  // Fingers that are showing a circle, keyed by pointer id
  final Map<int, _Touch> _touches = {};

  int? _winner;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? Random();
    _countdownController = AnimationController(vsync: this, duration: _countdown)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pickStartPlayer();
        }
      });
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  Color _nextColor() {
    final used = _touches.values.map((touch) => touch.color).toSet();
    return _touchColors.firstWhere(
      (color) => !used.contains(color),
      orElse: () => _touchColors[_touches.length % _touchColors.length],
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_winner != null) return;

    setState(() {
      _touches[event.pointer] = _Touch(event.localPosition, _nextColor());
    });
    _restartCountdown();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final touch = _touches[event.pointer];
    if (touch == null) return;

    setState(() {
      touch.position = event.localPosition;
    });
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);

    if (_winner != null) {
      // The chosen circle stays where it is until every finger is lifted
      if (_activePointers.isEmpty) _reset();
      return;
    }

    setState(() {
      _touches.remove(event.pointer);
    });
    _restartCountdown();
  }

  // A single finger shows its circle but waits for company before the
  // timer runs
  void _restartCountdown() {
    if (_touches.length >= _minTouches) {
      _countdownController.forward(from: 0);
    } else {
      _countdownController.reset();
    }
  }

  void _pickStartPlayer() {
    if (_touches.isEmpty) return;

    final pointers = _touches.keys.toList();
    final winner = pointers[_random.nextInt(pointers.length)];
    HapticFeedback.heavyImpact();
    setState(() {
      _winner = winner;
      _touches.removeWhere((pointer, _) => pointer != winner);
    });
  }

  void _reset() {
    _countdownController.reset();
    setState(() {
      _winner = null;
      _touches.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCountingDown = _winner == null && _touches.length >= _minTouches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Player'),
      ),
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_touches.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Everyone touch and hold the screen',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A start player is chosen after 3 seconds',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            for (final entry in _touches.entries)
              Positioned(
                key: ValueKey<int>(entry.key),
                left: entry.value.position.dx - _TouchCircle.extent / 2,
                top: entry.value.position.dy - _TouchCircle.extent / 2,
                child: _TouchCircle(
                  color: entry.value.color,
                  isWinner: entry.key == _winner,
                  countdown: isCountingDown ? _countdownController : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Touch {
  _Touch(this.position, this.color);

  Offset position;
  final Color color;
}

class _TouchCircle extends StatelessWidget {
  const _TouchCircle({
    required this.color,
    required this.isWinner,
    required this.countdown,
  });

  /// Fixed outer size, large enough for the winner circle, so the circle
  /// stays centered on the finger as it grows.
  static const double extent = 168;

  static const double _circleSize = 96;
  static const double _ringSize = 124;

  final Color color;
  final bool isWinner;

  /// Progress of the countdown, or null while the timer isn't running.
  final Animation<double>? countdown;

  @override
  Widget build(BuildContext context) {
    final countdown = this.countdown;

    return SizedBox.square(
      dimension: extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (countdown != null)
            SizedBox.square(
              dimension: _ringSize,
              child: AnimatedBuilder(
                animation: countdown,
                builder: (context, _) => CircularProgressIndicator(
                  value: 1 - countdown.value,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: isWinner ? extent : _circleSize,
            height: isWinner ? extent : _circleSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
