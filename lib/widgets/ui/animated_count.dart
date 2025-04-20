import 'package:flutter/material.dart';
import 'dart:math';

/// Widget qui affiche un compteur avec une animation
class AnimatedCount extends StatefulWidget {
  final int count;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedCount({
    Key? key,
    required this.count,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
  }) : super(key: key);

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _oldCount;
  late int _currentCount;

  @override
  void initState() {
    super.initState();
    _oldCount = 0;
    _currentCount = widget.count;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _oldCount = oldWidget.count;
      _currentCount = widget.count;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _oldCount + (_currentCount - _oldCount) * _animation.value;
        return Text(
          value.toInt().toString(),
          style: widget.style,
        );
      },
    );
  }
} 