import 'package:flutter/material.dart';

/// A widget that renders a highly-performant, ultra-subtle Gemini-style background gradient.
/// This completely eliminates heavy multi-layer composite drawing, ensuring maximum scroll performance.
class MeshBackground extends StatelessWidget {
  final Widget child;

  const MeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Premium Gemini-inspired color transitions
    final gradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF13131A), // Soft, deep navy/indigo slate tint
              Color(0xFF0B0B0D), // Deep premium onyx slate
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(
                  0xFFF0F4F9), // Ice-blue white tint (Gemini light mode signature)
              Color(0xFFFBFBFD), // Pure clean white slate
            ],
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
        ),
        child: child,
      ),
    );
  }
}
