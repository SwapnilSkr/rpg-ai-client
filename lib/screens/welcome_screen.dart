import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme/nexus_theme.dart';
import '../shared/widgets/realm_backdrop.dart';
import '../shared/widgets/neu.dart';

/// The landing page shown to unauthenticated users — the gate before the
/// threshold. No technical jargon; pure fantasy invitation.
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
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: RealmBackdrop(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  const ForgeMark(size: 96),
                  const SizedBox(height: 24),
                  Text(
                    'EVERLORE',
                    style: GoogleFonts.cinzel(
                      color: EverloreTheme.gold,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Every choice echoes through eternity',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ebGaramond(
                      color: EverloreTheme.ash,
                      fontSize: 16,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const Spacer(flex: 2),

                  Column(
                    children: const [
                      _FeatureRow(
                        icon: Icons.psychology_alt,
                        color: EverloreTheme.violet,
                        text: 'A living world that remembers everything',
                      ),
                      SizedBox(height: 16),
                      _FeatureRow(
                        icon: Icons.history_edu,
                        color: EverloreTheme.gold,
                        text: 'Your story, written by your choices',
                      ),
                      SizedBox(height: 16),
                      _FeatureRow(
                        icon: Icons.explore,
                        color: EverloreTheme.cyanBright,
                        text: 'Infinite worlds crafted by our community',
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  NeuButton(
                    label: 'BEGIN YOUR JOURNEY',
                    icon: Icons.auto_awesome,
                    onTap: () => context.push('/auth'),
                  ),
                  const SizedBox(height: 14),
                  NeuButton(
                    label: 'Explore Worlds',
                    primary: false,
                    onTap: () => context.push('/templates'),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
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
        // Raised neumorphic glyph token.
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.4),
              colors: [
                color.withValues(alpha: 0.18),
                EverloreTheme.void2,
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontFamily: EverloreTheme.uiFamily, 
              color: EverloreTheme.parchment.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
