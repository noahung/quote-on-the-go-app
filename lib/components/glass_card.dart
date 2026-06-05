import 'dart:ui';
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

    final effectiveBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        );

    final backgroundColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.45);

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

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: cardContent,
      ),
    );
  }
}
