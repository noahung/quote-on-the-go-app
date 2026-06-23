import 'package:flutter/material.dart';

/// A premium, glassmorphic frosted card container.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(24);

    final effectiveBorder = border; // No borders by default for a clean Gemini look

    final backgroundColor = isDark
        ? const Color(0xFF1E1E24)
        : const Color(0xFFF0F4F9);

    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveBorderRadius,
        border: effectiveBorder,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
