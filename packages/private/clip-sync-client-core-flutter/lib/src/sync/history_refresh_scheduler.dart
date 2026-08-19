import 'dart:async';

import 'package:flutter/foundation.dart';

/// Refreshes visible history frequently at first, then pauses after inactivity.
class HistoryRefreshScheduler extends ChangeNotifier {
  HistoryRefreshScheduler({
    required this.onRefresh,
    this.fastInterval = const Duration(seconds: 5),
    this.fastPhaseDuration = const Duration(seconds: 30),
    this.slowInterval = const Duration(seconds: 30),
    this.pauseAfter = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    assert(fastInterval > Duration.zero);
    assert(fastPhaseDuration > Duration.zero);
    assert(slowInterval > Duration.zero);
    assert(pauseAfter > fastPhaseDuration);
  }

  /// Performs one history refresh and handles any user-facing error state.
  final Future<void> Function() onRefresh;
  final Duration fastInterval;
  final Duration fastPhaseDuration;
  final Duration slowInterval;
  final Duration pauseAfter;
  final DateTime Function() _now;

  Timer? _timer;
  DateTime? _visibleSince;
  bool _isVisible = false;
  bool _isPaused = false;
  bool _isDisposed = false;
  int _generation = 0;

  bool get isPaused => _isPaused;

  /// Starts a new refresh window when history becomes visible.
  void start() {
    if (_isDisposed || _isVisible) return;
    _isVisible = true;
    _isPaused = false;
    _visibleSince = _now();
    _generation += 1;
    _schedule(fastInterval, _generation);
    notifyListeners();
  }

  /// Stops refreshing while history is not visible.
  void stop() {
    if (_isDisposed) return;
    final changed = _isVisible || _isPaused;
    _timer?.cancel();
    _timer = null;
    _isVisible = false;
    _isPaused = false;
    _visibleSince = null;
    _generation += 1;
    if (changed) notifyListeners();
  }

  /// Refreshes immediately and starts a new two-minute refresh window.
  Future<void> refreshNow() async {
    if (_isDisposed) return;
    _timer?.cancel();
    _timer = null;
    _isVisible = true;
    _isPaused = false;
    _visibleSince = _now();
    _generation += 1;
    final generation = _generation;
    notifyListeners();
    try {
      await onRefresh();
    } finally {
      if (_canSchedule(generation)) {
        _schedule(fastInterval, generation);
      }
    }
  }

  void _schedule(Duration delay, int generation) {
    _timer?.cancel();
    _timer = Timer(delay, () => _onTimer(generation));
  }

  Future<void> _onTimer(int generation) async {
    _timer = null;
    if (!_canSchedule(generation)) return;
    if (_elapsed >= pauseAfter) {
      _pause();
      return;
    }

    await onRefresh();
    if (!_canSchedule(generation)) return;
    if (_elapsed >= pauseAfter) {
      _pause();
      return;
    }
    final nextInterval = _elapsed < fastPhaseDuration
        ? fastInterval
        : slowInterval;
    _schedule(nextInterval, generation);
  }

  Duration get _elapsed => _now().difference(_visibleSince!);

  bool _canSchedule(int generation) =>
      !_isDisposed && _isVisible && !_isPaused && generation == _generation;

  void _pause() {
    _timer?.cancel();
    _timer = null;
    _isPaused = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isDisposed = true;
    _generation += 1;
    super.dispose();
  }
}
