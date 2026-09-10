import 'package:flutter/material.dart';

import '../../../../shared/widgets/everlore_network_image.dart';
import 'stage_tokens.dart';

/// The scene painting, full bleed, with the graded darkening that puts
/// figures in front of it.
///
/// Two surfaces each inventing their own veil is how a fight and a
/// conversation stopped belonging to the same place. A null painting
/// renders bare ground rather than a broken frame.
class StageBackdrop extends StatelessWidget {
  const StageBackdrop({super.key, this.url, this.veil = StageVeil.arena});

  final String? url;

  /// A meeting uses [StageVeil.room]. The arena veil over a room is
  /// what lowered a speaker into the dark and left only the parchment.
  final StageVeil veil;

  @override
  Widget build(BuildContext context) {
    final colors = veil == StageVeil.arena
        ? const [
            StageMeasure.veilTop,
            StageMeasure.veilMid,
            StageMeasure.veilBottom,
          ]
        : const [
            StageMeasure.roomVeilTop,
            StageMeasure.roomVeilMid,
            StageMeasure.roomVeilBottom,
          ];
    final stops = veil == StageVeil.arena
        ? StageMeasure.veilStops
        : StageMeasure.roomVeilStops;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          EverloreNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            placeholder: const ColoredBox(
              color: StageMeasure.groundRaised,
              child: SizedBox.expand(),
            ),
            errorWidget: const ColoredBox(
              color: StageMeasure.groundRaised,
              child: SizedBox.expand(),
            ),
          )
        else
          const ColoredBox(
            color: StageMeasure.groundRaised,
            child: SizedBox.expand(),
          ),
        // The sand is lit; the tiers around it are not. Darkening top and
        // bottom is what puts the figures in the middle of a place without
        // painting a crowd. A childless DecoratedBox collapses to nothing
        // under a loose constraint and the veil never lands.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
              stops: stops,
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}
