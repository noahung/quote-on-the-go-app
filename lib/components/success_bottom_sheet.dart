import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/feedback_type.dart';
import 'animated_celebration_icon.dart';
import 'pill_button.dart';

/// Bottom sheet style success modal
/// Rounded corners at top, glass background, centered on screen
/// Uses brand orange primary color
class SuccessBottomSheet extends StatefulWidget {
  final CelebrationType type;
  final String title;
  final String? subtitle;
  final String buttonText;

  const SuccessBottomSheet({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.buttonText = 'Got it',
  });

  /// Show as modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required CelebrationType type,
    required String title,
    String? subtitle,
    String buttonText = 'Got it',
  }) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: SuccessBottomSheet(
          type: type,
          title: title,
          subtitle: subtitle,
          buttonText: buttonText,
        ),
      ),
    );
  }

  @override
  State<SuccessBottomSheet> createState() => _SuccessBottomSheetState();
}

class _SuccessBottomSheetState extends State<SuccessBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideAnimation.value) * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Spacer to push content to center
                  const Spacer(flex: 1),

                  // Success card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated icon (smaller version)
                          AnimatedCelebrationIcon(
                            type: widget.type,
                            size: 70,
                          ),

                          const SizedBox(height: 24),

                          // Title
                          Text(
                            widget.title,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          // Subtitle
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.subtitle!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Pill button
                          SizedBox(
                            width: double.infinity,
                            child: PillButton(
                              text: widget.buttonText,
                              onTap: _dismiss,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Quick helper methods for showing bottom sheet success
class SuccessSheet {
  static Future<void> show({
    required BuildContext context,
    required CelebrationType type,
    required String title,
    String? subtitle,
    String buttonText = 'Got it',
  }) {
    return SuccessBottomSheet.show(
      context: context,
      type: type,
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
    );
  }

  static Future<void> checkmark({
    required BuildContext context,
    required String title,
    String? subtitle,
    String buttonText = 'Got it',
  }) {
    return SuccessBottomSheet.show(
      context: context,
      type: CelebrationType.checkmark,
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
    );
  }

  static Future<void> sparkle({
    required BuildContext context,
    required String title,
    String? subtitle,
    String buttonText = 'Got it',
  }) {
    return SuccessBottomSheet.show(
      context: context,
      type: CelebrationType.sparkle,
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
    );
  }

  static Future<void> send({
    required BuildContext context,
    required String title,
    String? subtitle,
    String buttonText = 'Got it',
  }) {
    return SuccessBottomSheet.show(
      context: context,
      type: CelebrationType.send,
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
    );
  }
}
