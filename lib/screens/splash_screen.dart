import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_menu_screen.dart';
import 'login_screen.dart';
import 'user_restaurants_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // Show luxury splash for at least 2.2 seconds
    final minDelay = Future.delayed(const Duration(milliseconds: 2200));

    final user = FirebaseAuth.instance.currentUser;
    Widget destination;

    if (user != null) {
      try {
        final isOwner =
            await AuthService().isCurrentUserRestaurantOwner(user.uid);
        if (isOwner) {
          destination = const HomeMenuScreen();
        } else {
          destination = const UserRestaurantsScreen();
        }
      } catch (e) {
        destination = const UserRestaurantsScreen();
      }
    } else {
      destination = const LoginScreen();
    }

    await minDelay;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      body: Stack(
        children: [
          // Full Screen Dark Obsidian Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B0C10),
                    Color(0xFF170E18),
                    Color(0xFF0B0C10),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Glowing Ambient Neon Orbs
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFA4468).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF5277).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central Splash Logo & Branding
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),

                          // Glowing Logo Container with Black & Pink Theme
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ambient glow ring
                              Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFFA4468).withValues(
                                        alpha: _glowAnimation.value * 0.35,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // Logo Card
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16171D),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: const Color(0xFFFA4468).withValues(
                                      alpha: _glowAnimation.value * 0.8,
                                    ),
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFA4468).withValues(
                                        alpha: _glowAnimation.value * 0.5,
                                      ),
                                      blurRadius: 45,
                                      spreadRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.9),
                                      blurRadius: 25,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(38),
                                  child: Image.asset(
                                    'assets/icon/app_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 36),

                          // Luxury Brand Title (Replaced generic project name)
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Colors.white,
                                Color(0xFFFF85A1),
                                Colors.white,
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: const Text(
                              'CRAVE & DINE',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Catchy Tagline Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFA4468).withValues(alpha: 0.15),
                                  const Color(0xFFFA4468).withValues(alpha: 0.3),
                                  const Color(0xFFFA4468).withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFFA4468).withValues(alpha: 0.45),
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              'Flavors Crafted to Perfection ✨',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6283),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Sub-tagline
                          Text(
                            'ORDER  •  TASTE  •  EXPERIENCE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 3.0,
                            ),
                          ),

                          const Spacer(),

                          // Modern Pink Shimmer Loading Indicator
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.0,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFA4468),
                                    ),
                                    backgroundColor:
                                        const Color(0xFFFA4468).withValues(alpha: 0.15),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Preparing your luxury dining experience...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.55),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
