import 'package:flutter/material.dart';

/// Compatibility wrapper for the flat application canvas.
class MeshBackground extends StatelessWidget {
  final Widget child;
  const MeshBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor, child: child);
}
