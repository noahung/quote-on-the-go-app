import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Flat tonal panel. The legacy name remains for existing callers.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  const GlassCard(
      {super.key,
      required this.child,
      this.padding,
      this.width,
      this.height,
      this.borderRadius,
      this.border,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular(DesignTokens.panelRadius);
    return SizedBox(
        width: width,
        height: height,
        child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: Ink(
                decoration: BoxDecoration(border: border, borderRadius: radius),
                child: InkWell(
                    onTap: onTap,
                    borderRadius: radius,
                    child: Padding(
                        padding: padding ?? const EdgeInsets.all(20),
                        child: child)))));
  }
}
