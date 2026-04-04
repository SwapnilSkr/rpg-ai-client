import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme/nexus_theme.dart';

/// The landing page shown to unauthenticated users.
/// No technical jargon — pure fantasy invitation.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          children: [
            // Ambient background radial gradients
            Positioned(
              top: -100,
              left: -80,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      EverloreTheme.violet.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.15,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      EverloreTheme.gold.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [EverloreTheme.void3, EverloreTheme.void1],
                      ),
                      border: Border.all(
                        color: EverloreTheme.gold.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: EverloreTheme.gold.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_stories,
                      color: EverloreTheme.gold,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'EVERLORE',
                    style: TextStyle(
                      color: EverloreTheme.gold,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8.0,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Every choice echoes through eternity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Feature highlights
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        _FeatureRow(
                          icon: Icons.psychology_alt,
                          color: EverloreTheme.violet,
                          text: 'A living world that remembers everything',
                        ),
                        const SizedBox(height: 16),
                        _FeatureRow(
                          icon: Icons.history_edu,
                          color: EverloreTheme.gold,
                          text: 'Your story, written by your choices',
                        ),
                        const SizedBox(height: 16),
                        _FeatureRow(
                          icon: Icons.explore,
                          color: EverloreTheme.cyanBright,
                          text: 'Infinite worlds crafted by our community',
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // CTA buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.push('/auth'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EverloreTheme.gold,
                              foregroundColor: EverloreTheme.void0,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'BEGIN YOUR JOURNEY',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.push('/templates'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EverloreTheme.ash,
                              side: BorderSide(
                                color: EverloreTheme.white20,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Explore Worlds',
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: EverloreTheme.ash,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
