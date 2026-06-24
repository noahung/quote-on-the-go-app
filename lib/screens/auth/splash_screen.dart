import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Controller for the fluid mesh gradient movement
  late AnimationController _gradientController;

  // Controller for the logo fade-in and scale animations
  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;

  // Overall screen opacity for a smooth fade-out transition
  double _screenOpacity = 1.0;

  Timer? _navigationTimer;
  Timer? _fadeOutTimer;

  @override
  void initState() {
    super.initState();

    // 1. Fluid Mesh Gradient Animation (runs indefinitely)
    _gradientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // 2. Logo Entrance Animation (runs on start)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );

    // Start logo animation
    _logoController.forward();

    // Start fade-out timer at 2.7 seconds (300ms before transition at 3.0s)
    // Decreased splash duration slightly since there is no typing slogan now.
    _fadeOutTimer = Timer(const Duration(milliseconds: 2700), () {
      if (mounted) {
        setState(() {
          _screenOpacity = 0.0;
        });
      }
    });

    // Start main navigation timer to route to app at 3.0 seconds
    _navigationTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _logoController.dispose();
    _navigationTimer?.cancel();
    _fadeOutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF5A36), // Fallback vibrant neon-orange
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _screenOpacity,
        child: Stack(
          children: [
            // 1. Liquid Mesh Gradient Layer
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      final t = _gradientController.value * 2 * math.pi;

                      // Calculate animated paths for multiple radial gradient blobs
                      final blob1X = width * 0.2 + math.sin(t) * width * 0.15;
                      final blob1Y = height * 0.3 + math.cos(t) * height * 0.1;

                      final blob2X = width * 0.75 + math.cos(t + math.pi / 2) * width * 0.2;
                      final blob2Y = height * 0.25 + math.sin(t + math.pi / 2) * height * 0.15;

                      final blob3X = width * 0.35 + math.cos(t + math.pi) * width * 0.18;
                      final blob3Y = height * 0.7 + math.sin(t + math.pi) * height * 0.12;

                      final blob4X = width * 0.5 + math.sin(t * 1.5) * width * 0.1;
                      final blob4Y = height * 0.55 + math.cos(t * 1.5) * height * 0.1;

                      return Stack(
                        children: [
                          // Base gradient background
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFF4E2B), // Deep neon orange-red
                                    Color(0xFFFF8243), // Vibrant pumpkin orange
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Moving Blob 1: Luminous Yellow Glow
                          Positioned(
                            left: blob1X - 200,
                            top: blob1Y - 200,
                            child: Container(
                              width: 400,
                              height: 400,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0xFFFFD000), // Pure gold/yellow
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Moving Blob 2: Soft Neon Peach
                          Positioned(
                            left: blob2X - 220,
                            top: blob2Y - 220,
                            child: Container(
                              width: 440,
                              height: 440,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0xFFFF9E79), // Glowing peach
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Moving Blob 3: Hot Pink Accent
                          Positioned(
                            left: blob3X - 180,
                            top: blob3Y - 180,
                            child: Container(
                              width: 360,
                              height: 360,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0xFFFF2D55), // Hot pink/coral
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Moving Blob 4: White Luminous Core (glowing highlight)
                          Positioned(
                            left: blob4X - 150,
                            top: blob4Y - 150,
                            child: Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.45), // White light
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // High-quality Blur Filter to blend everything into a liquid mesh
                          Positioned.fill(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // 2. Foreground Centered Brand Content Layer
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      'assets/images/white_logo.png',
                      height: 160, // Premium enlarged logo size
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // High-fidelity fallback vector icon if logo fails to load
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.rocket_launch_rounded,
                                  size: 56,
                                  color: Color(0xFFFF5A36),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Quote On The Go',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
