import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays the standard refresh icon and rotates it while a request is active.
///
/// Listening to a dedicated [ValueListenable] keeps the animation isolated from
/// the surrounding history view, so refresh activity alone does not rebuild it.
class RefreshActivityIcon extends StatefulWidget {
  const RefreshActivityIcon({required this.isRefreshing, super.key});

  final ValueListenable<bool> isRefreshing;

  @override
  State<RefreshActivityIcon> createState() => _RefreshActivityIconState();
}

class _RefreshActivityIconState extends State<RefreshActivityIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    widget.isRefreshing.addListener(_refreshActivityChanged);
    _refreshActivityChanged();
  }

  @override
  void didUpdateWidget(RefreshActivityIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing == widget.isRefreshing) return;
    oldWidget.isRefreshing.removeListener(_refreshActivityChanged);
    widget.isRefreshing.addListener(_refreshActivityChanged);
    _refreshActivityChanged();
  }

  void _refreshActivityChanged() {
    if (widget.isRefreshing.value) {
      if (!_rotation.isAnimating) _rotation.repeat();
      return;
    }
    if (!_rotation.isAnimating && _rotation.value == 0) return;

    final remainingMilliseconds = ((1 - _rotation.value) * 800).ceil();
    _rotation
        .animateTo(
          1,
          duration: Duration(
            milliseconds: remainingMilliseconds == 0
                ? 1
                : remainingMilliseconds,
          ),
          curve: Curves.linear,
        )
        .whenComplete(() {
          if (mounted && !widget.isRefreshing.value) _rotation.value = 0;
        });
  }

  @override
  void dispose() {
    widget.isRefreshing.removeListener(_refreshActivityChanged);
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    key: const ValueKey('history-refresh-icon'),
    turns: _rotation,
    child: const Icon(Icons.refresh),
  );
}
