import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../app/theme/nexus_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _glowController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _taglineFade;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _glowPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _logoController.forward().then((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final user = await AuthService.getCachedUser();
    if (!mounted) return;
    if (user != null) {
      context.go('/');
    } else {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_logoController, _glowController]),
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glow orb + logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow backdrop
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: EverloreTheme.gold.withValues(
                                    alpha: 0.15 * _glowPulse.value),
                                blurRadius: 80,
                                spreadRadius: 20,
                              ),
                              BoxShadow(
                                color: EverloreTheme.violet.withValues(
                                    alpha: 0.1 * _glowPulse.value),
                                blurRadius: 120,
                                spreadRadius: 30,
                              ),
                            ],
                          ),
                        ),
                        // Outer ring
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: EverloreTheme.goldDim.withValues(
                                  alpha: 0.5 * _glowPulse.value),
                              width: 1,
                            ),
                          ),
                        ),
                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                EverloreTheme.void3,
                                EverloreTheme.void1,
                              ],
                            ),
                            border: Border.all(
                              color: EverloreTheme.gold.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_stories,
                            color: EverloreTheme.gold,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                FadeTransition(
                  opacity: _logoFade,
                  child: const Text(
                    'EVERLORE',
                    style: TextStyle(
                      color: EverloreTheme.gold,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8.0,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                FadeTransition(
                  opacity: _taglineFade,
                  child: const Text(
                    'A Living World Awaits',
                    style: TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 13,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                FadeTransition(
                  opacity: _taglineFade,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: EverloreTheme.goldDim.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
