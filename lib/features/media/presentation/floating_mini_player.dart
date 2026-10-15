import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../services/audio_playback_controller.dart';

/// Floating mini-player that appears only while a spoken line is playing,
/// and disappears as soon as audio completes or stops.
class FloatingMiniPlayer extends StatefulWidget {
  final AudioPlaybackController controller;

  const FloatingMiniPlayer({super.key, required this.controller});

  @override
  State<FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends State<FloatingMiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    widget.controller.addListener(_onController);
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isPlaying) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 70),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: EverloreTheme.gold.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => widget.controller.stop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      return Icon(
                        Icons.graphic_eq_rounded,
                        size: 16,
                        color: Color.lerp(
                          EverloreTheme.goldDim,
                          EverloreTheme.gold,
                          _pulse.value,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Speaking',
                    style: EverloreTheme.ui(
                      size: 12,
                      weight: FontWeight.w600,
                      color: EverloreTheme.parchment,
                      spacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.stop_circle_outlined,
                    size: 16,
                    color: EverloreTheme.ash.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
