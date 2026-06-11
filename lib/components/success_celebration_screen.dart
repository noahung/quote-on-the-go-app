import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/feedback_type.dart';
import 'animated_celebration_icon.dart';
import 'pill_button.dart';

/// Full-screen success celebration overlay
/// Displays animated icon, title, subtitle, and Done button
/// Uses brand colors and matches app's Material 3 design system
class SuccessCelebrationScreen extends StatefulWidget {
  final CelebrationType type;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onDone;
  final Duration autoDismissDuration;
  final bool allowAutoDismiss;

  const SuccessCelebrationScreen({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onDone,
    this.autoDismissDuration = const Duration(seconds: 3),
    this.allowAutoDismiss = false,
  });

  /// Show as overlay
  static Future<void> show({
    required BuildContext context,
    required CelebrationType type,
    required String title,
    String? subtitle,
    String? buttonText,
    VoidCallback? onDone,
    bool allowAutoDismiss = false,
    Duration autoDismissDuration = const Duration(seconds: 3),
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => SuccessCelebrationScreen(
        type: type,
        title: title,
        subtitle: subtitle,
        buttonText: buttonText,
        onDone: onDone,
        allowAutoDismiss: allowAutoDismiss,
        autoDismissDuration: autoDismissDuration,
      ),
    );
  }

  @override
  State<SuccessCelebrationScreen> createState() => _SuccessCelebrationScreenState();
}

class _SuccessCelebrationScreenState extends State<SuccessCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _fadeController.forward();

    // Auto-dismiss if enabled
    if (widget.allowAutoDismiss) {
      Future.delayed(widget.autoDismissDuration, () {
        if (mounted) _dismiss();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    
    // Fade out
    _fadeController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDone?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.85),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Animated celebration icon
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: AnimatedCelebrationIcon(
                          type: widget.type,
                          size: 100,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Title
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value * 0.5),
                        child: Text(
                          widget.title,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle (if provided)
                      if (widget.subtitle != null)
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 0.3),
                          child: Text(
                            widget.subtitle!,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const Spacer(flex: 3),

                      // Done button
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value * 0.2),
                        child: SizedBox(
                          width: double.infinity,
                          child: PillButton(
                            text: widget.buttonText ?? 'Done',
                            onTap: _dismiss,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
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
}

/// Simplified version that can be used as a widget directly
class SuccessCelebrationOverlay extends StatelessWidget {
  final CelebrationType type;
  final String title;
  final String? subtitle;
  final String buttonText;
  final VoidCallback onDone;

  const SuccessCelebrationOverlay({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.buttonText = 'Done',
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark 
          ? Colors.black.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated celebration icon
              AnimatedCelebrationIcon(
                type: type,
                size: 100,
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Subtitle
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

              const Spacer(flex: 3),

              // Done button
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  text: buttonText,
                  onTap: onDone,
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
