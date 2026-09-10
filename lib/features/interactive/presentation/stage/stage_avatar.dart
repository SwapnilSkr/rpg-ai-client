import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import 'stage_tokens.dart';

/// A circular portrait medallion in a brass ring.
///
/// A null face still belongs to someone on the sand. The ring holds
/// their initial rather than a broken frame.
class StageAvatar extends StatelessWidget {
  const StageAvatar({super.key, required this.name, this.portraitUrl});

  final String name;
  final String? portraitUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '' : trimmed[0].toUpperCase();
    return SizedBox(
      width: StageMeasure.avatarSize,
      height: StageMeasure.avatarSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: StageMeasure.brass,
            width: StageMeasure.avatarRing,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: portraitUrl == null
              ? _Initial(initial: initial)
              // Cover-cropping a 2:3 body in a circle lands on the
              // chest, so the medallion would wear a torso.
              : OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight:
                      StageMeasure.avatarSize / StageMeasure.figureAspect,
                  child: SizedBox(
                    width: StageMeasure.avatarSize,
                    height: StageMeasure.avatarSize / StageMeasure.figureAspect,
                    child: EverloreNetworkImage(
                      imageUrl: portraitUrl!,
                      fit: BoxFit.contain,
                      semanticLabel: name,
                      placeholder: _Initial(initial: initial),
                      errorWidget: _Initial(initial: initial),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StageMeasure.groundRaised,
      child: Center(
        child: Text(
          initial,
          style: EverloreTheme.serifDisplay(
            size: 18,
            color: StageMeasure.brassDim,
          ),
        ),
      ),
    );
  }
}
