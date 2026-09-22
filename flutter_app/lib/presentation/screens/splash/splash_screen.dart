import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward();

    // Navigate after animation + auth check
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuth();
      }
    });
  }

  void _checkAuth() {
    final authState = ref.read(authProvider);
    if (!mounted) return;
    if (authState is AuthAuthenticated) {
      context.go('/home');
    } else if (authState is AuthUnauthenticated) {
      context.go('/login');
    }
    // If still loading, listen for state change
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // React to auth state changes after animation completes
    ref.listen(authProvider, (_, next) {
      if (!_ctrl.isAnimating && mounted) {
        if (next is AuthAuthenticated) context.go('/home');
        if (next is AuthUnauthenticated) context.go('/login');
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF1A6B4A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo + app name
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) => FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Golden Hand',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Text(
                          'Caregivers',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Tagline
              AnimatedBuilder(
                animation: _taglineFade,
                builder: (_, _) => FadeTransition(
                  opacity: _taglineFade,
                  child: const Text(
                    'Trusted Care, Every Day',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Loading indicator
              AnimatedBuilder(
                animation: _taglineFade,
                builder: (_, _) => FadeTransition(
                  opacity: _taglineFade,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.8),
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Loading…',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
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
