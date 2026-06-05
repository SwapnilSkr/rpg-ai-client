import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';
import '../models/user.dart';

/// Bundled anime portrait for the signed-in player (generated once via
/// `gen:player-avatars` on the server). Skipped gender → neutral shonen.
class PlayerAvatar extends StatelessWidget {
  final PlayerGender? gender;
  final double size;
  final bool showRim;

  const PlayerAvatar({
    super.key,
    required this.gender,
    this.size = 80,
    this.showRim = true,
  });

  static String assetPath(PlayerGender? gender) {
    final key = switch (gender) {
      PlayerGender.male => 'male',
      PlayerGender.female => 'female',
      PlayerGender.nonBinary => 'non_binary',
      null => 'neutral',
    };
    return 'assets/player-avatars/$key.webp';
  }

  @override
  Widget build(BuildContext context) {
    final path = assetPath(gender);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showRim
            ? Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.55),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: size * 0.22,
            offset: Offset(size * 0.075, size * 0.1),
          ),
          BoxShadow(
            color: EverloreTheme.gold.withValues(alpha: 0.12),
            blurRadius: size * 0.28,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallbackDisc(size),
        ),
      ),
    );
  }

  Widget _fallbackDisc(double size) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [EverloreTheme.void3, EverloreTheme.void0],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        size: size * 0.42,
        color: EverloreTheme.goldDim,
      ),
    );
  }
}
