import 'package:flutter/material.dart';

/// Subtle Material 3 expressive bounce for press interactions.
class ExpressiveBounce extends StatefulWidget {
  const ExpressiveBounce({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 150),
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final Duration duration;

  @override
  State<ExpressiveBounce> createState() => _ExpressiveBounceState();
}

class _ExpressiveBounceState extends State<ExpressiveBounce> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: reduceMotion ? 1 : (_pressed ? widget.pressedScale : 1),
        duration: reduceMotion ? Duration.zero : widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
