import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/feedback_type.dart';

/// Clean, attractive floating pill-shaped toast notification matching the Google Gemini aesthetic.
/// Appears at the bottom center of the screen and does not block touch interactions.
class FlashMessage extends StatefulWidget {
  final FlashMessageType type;
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FlashMessage({
    super.key,
    required this.type,
    required this.message,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  static OverlayEntry? _currentEntry;
  static Timer? _hideTimer;

  static void show({
    required BuildContext context,
    required FlashMessageType type,
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    hide();

    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Positioned at the bottom center, floating above standard bottom sheets/navbars
            Positioned(
              bottom: mediaQuery.padding.bottom + 80,
              left: 24,
              right: 24,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FlashMessage(
                  type: type,
                  message: message,
                  duration: duration,
                  onDismiss: hide,
                  actionLabel: actionLabel,
                  onAction: onAction != null
                      ? () {
                          hide();
                          onAction();
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_currentEntry!);

    final actualDuration = onAction != null
        ? const Duration(seconds: 5)
        : duration;
    _hideTimer?.cancel();
    _hideTimer = Timer(actualDuration, hide);
  }

  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  @override
  State<FlashMessage> createState() => _FlashMessageState();
}

class _FlashMessageState extends State<FlashMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
    
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (icon, iconColor) = _getColors(colorScheme);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2C2C35) // Gemini dark theme pill background
                : Colors.white,           // Gemini light theme pill background
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFF1F1F4)
                        : const Color(0xFF1F1F1F),
                  ),
                ),
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onAction,
                  child: Text(
                    widget.actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _getColors(ColorScheme colorScheme) {
    final brandOrange = colorScheme.primary; // #F4781F
    
    switch (widget.type) {
      case FlashMessageType.success:
        return (LucideIcons.checkCircle2, brandOrange);
      case FlashMessageType.error:
        return (LucideIcons.alertCircle, brandOrange);
      case FlashMessageType.info:
        return (LucideIcons.info, brandOrange);
      case FlashMessageType.warning:
        return (LucideIcons.triangleAlert, brandOrange);
    }
  }
}

/// Simple static helper for showing flash messages
class Flash {
  static void success(BuildContext context, String message) {
    FlashMessage.show(
      context: context,
      type: FlashMessageType.success,
      message: message,
    );
  }

  static void error(BuildContext context, String message) {
    FlashMessage.show(
      context: context,
      type: FlashMessageType.error,
      message: message,
    );
  }

  static void info(BuildContext context, String message) {
    FlashMessage.show(
      context: context,
      type: FlashMessageType.info,
      message: message,
    );
  }

  static void warning(BuildContext context, String message) {
    FlashMessage.show(
      context: context,
      type: FlashMessageType.warning,
      message: message,
    );
  }
}
