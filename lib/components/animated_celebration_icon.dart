import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import '../models/feedback_type.dart';

/// Animated celebration icon with particle burst effect
/// Uses brand orange (#F4781F) as primary color
class AnimatedCelebrationIcon extends StatefulWidget {
  final CelebrationType type;
  final double size;

  const AnimatedCelebrationIcon({
    super.key,
    required this.type,
    this.size = 80,
  });

  @override
  State<AnimatedCelebrationIcon> createState() => _AnimatedCelebrationIconState();
}

class _AnimatedCelebrationIconState extends State<AnimatedCelebrationIcon>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _particleController;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    
    // Haptic feedback on start
    HapticFeedback.mediumImpact();
    
    // Icon animation controller (elastic bounce)
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Scale animation with bounce effect (easeOutBack gives bounce without overshoot issues)
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: Curves.easeOutBack,
      ),
    );

    // Rotation animation (subtle spin)
    _iconRotation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Particle animation controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Start animations
    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _particleController.forward();
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Brand orange colors
    final brandOrange = colorScheme.primary; // #F4781F
    final brandOrangeLight = isDark 
        ? colorScheme.primaryContainer 
        : const Color(0xFFFFDBC8);

    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Particle burst
          ...List.generate(12, (index) {
            final angle = (index * 30) * (pi / 180);
            return AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                final progress = _particleController.value;
                final distance = widget.size * 0.8 * progress;
                final opacity = 1.0 - progress;
                final scale = 1.0 - (progress * 0.5);

                return Positioned(
                  left: widget.size + (cos(angle) * distance) - 6,
                  top: widget.size + (sin(angle) * distance) - 6,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: index % 3 == 0 
                              ? brandOrange 
                              : brandOrangeLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main icon
          AnimatedBuilder(
            animation: _iconController,
            builder: (context, child) {
              // Clamp scale to prevent any rendering issues
              final scale = _iconScale.value.clamp(0.0, 1.5);
              return Transform.scale(
                scale: scale,
                child: Transform.rotate(
                  angle: _iconRotation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          brandOrange,
                          Color.lerp(brandOrange, Colors.white, 0.2)!,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: brandOrange.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildIcon(brandOrange),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(Color backgroundColor) {
    final iconColor = Colors.white;
    final iconSize = widget.size * 0.5;

    switch (widget.type) {
      case CelebrationType.checkmark:
        return Icon(
          LucideIcons.check,
          color: iconColor,
          size: iconSize,
        );
      case CelebrationType.sparkle:
        return Icon(
          LucideIcons.sparkles,
          color: iconColor,
          size: iconSize,
        );
      case CelebrationType.send:
        return Transform.rotate(
          angle: -pi / 4,
          child: Icon(
            LucideIcons.send,
            color: iconColor,
            size: iconSize,
          ),
        );
    }
  }
}
