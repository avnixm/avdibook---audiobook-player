import 'package:flutter/material.dart';

import 'expressive_bounce.dart';

/// A soft rounded icon-only button.
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: ExpressiveBounce(
        enabled: true,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            minimumSize: Size(size, size),
          ),
          icon: Icon(icon, size: 22),
        ),
      ),
    );
  }
}
