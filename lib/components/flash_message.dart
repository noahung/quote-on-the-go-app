import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/feedback_type.dart';

/// Attractive flash message overlay - replaces standard SnackBar
/// Fade in/out at center with glass morphism design
/// Auto-dismisses after 3 seconds with progress indicator
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

  /// Show flash message as overlay
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
    // Remove existing message if any
    hide();

    final overlay = Overlay.of(context);
    
    final mediaQuery = MediaQuery.of(context);
    
    _currentEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Backdrop to capture taps
            Positioned.fill(
              child: GestureDetector(
                onTap: hide,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
            // Centered flash message
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: mediaQuery.viewInsets.bottom + 24,
                ),
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

    // Auto hide - longer duration if has action
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
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
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

    _progressAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.linear),
      ),
    );

    // Start entrance animation
    _controller.forward();

    // Start progress animation after entrance
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.animateTo(
          0,
          duration: widget.duration,
          curve: Curves.linear,
        ).then((_) {
          if (mounted) _dismiss();
        });
      }
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

    final (icon, iconColor, accentColor) = _getColors(colorScheme);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: GestureDetector(
            onTap: _dismiss,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E).withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Progress bar at top
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 1 - _controller.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Content
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              // Left accent line
                              Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Icon
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: iconColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Message
                              Expanded(
                                child: Text(
                                  widget.message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                    height: 1.3,
                                  ),
                                ),
                              ),

                              // Action button (if provided)
                              if (widget.actionLabel != null && widget.onAction != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: widget.onAction,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        widget.actionLabel!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Dismiss button
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _dismiss,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      LucideIcons.x,
                                      size: 18,
                                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
      },
    );
  }

  (IconData, Color, Color) _getColors(ColorScheme colorScheme) {
    final brandOrange = colorScheme.primary; // #F4781F
    
    // All messages use brand orange theme
    switch (widget.type) {
      case FlashMessageType.success:
        return (
          LucideIcons.checkCircle,
          brandOrange,
          brandOrange,
        );
      case FlashMessageType.error:
        return (
          LucideIcons.alertCircle,
          brandOrange,
          brandOrange,
        );
      case FlashMessageType.info:
        return (
          LucideIcons.info,
          brandOrange,
          brandOrange,
        );
      case FlashMessageType.warning:
        return (
          LucideIcons.triangleAlert,
          brandOrange,
          brandOrange,
        );
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
