import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';

/// Shared staging measurements.
///
/// A number written in two surfaces is how the parchment and the plate
/// drifted apart: each remembered its own cream, its own brass, its own
/// height, and the rooms stopped looking like they were in the same world.
abstract final class StageMeasure {
  /// Aged paper, warm enough to lift off a dark painting without reading
  /// as a modern card.
  static const Color paper = Color(0xFFF2E7D0);
  static const Color paperDeep = Color(0xFFE2D3B4);
  static const Color paperGrainLight = Color(0x33FFFFFF);
  static const Color paperGrainDark = Color(0x14000000);

  /// Dark ink on the paper. Parchment-coloured type on parchment is a
  /// letter that cannot be read.
  static const Color ink = Color(0xFF2A2118);
  static const Color inkMuted = Color(0xFF5A4A38);
  static const Color inkSoft = Color(0x992A2118);
  static const Color inkFaint = Color(0xCC2A2118);

  /// Cream fill for a shout. Saturated white on a painting is a sticker.
  static const Color cream = Color(0xF2F0E4CC);

  static const Color brass = EverloreTheme.gold;
  static const Color brassDim = EverloreTheme.goldDim;
  static const Color brassDeep = EverloreTheme.goldDeep;
  static const Color brassHot = EverloreTheme.goldHot;
  static const Color ember = EverloreTheme.ember;
  static const Color danger = EverloreTheme.crimson;
  static const Color parchment = EverloreTheme.parchment;
  static const Color ground = EverloreTheme.void0;
  static const Color groundRaised = EverloreTheme.void2;

  /// The veil that puts figures in front of the painting. Inventing a
  /// second one is how a conversation and a fight ended up in different
  /// rooms of the same place.
  static const Color veilTop = Color(0xDD000000);
  static const Color veilMid = Color(0x33000000);
  static const Color veilBottom = Color(0xEE000000);
  static const List<double> veilStops = [0.0, 0.42, 1.0];

  /// Room veil: only the band the parchment sits on. A fight-weight
  /// darkening over a meeting swallowed the speaker into the painting.
  static const Color roomVeilTop = Color(0x00000000);
  static const Color roomVeilMid = Color(0x00000000);
  static const Color roomVeilBottom = Color(0x59000000);
  static const List<double> roomVeilStops = [0.0, 0.58, 1.0];

  /// Conversation speaker — inside the 55–65 band so a figure is a person
  /// in the room, not a doll and not a wall.
  static const double figureSpeak = 0.60;

  /// Two in a room. Speak-width twice would stack them in the middle
  /// and hide the painting they are standing in.
  static const double figureRoomPair = 0.46;

  /// Three or more. A sliver per head is how a crowd became untappable
  /// dolls; this is the floor that keeps each one a person.
  static const double figureRoomCrowd = 0.32;

  /// Petition copy, and the longest a scene's own parchment may climb.
  /// Written on the panels and on the standing band so a face cannot
  /// be reserved against a different ceiling than the paper uses.
  static const double roomPanelCeiling = 0.66;

  /// The air under a scene parchment. Leaving it out of the reserved
  /// band is how a figure was sized into a gap that still covered it.
  static const double roomPanelFoot = 20;

  /// Far fighter: right half, head high. Left edge at half so the two
  /// cannot share the middle the way an Align in a full-bleed Stack did.
  static const double duelFarLeft = 0.50;
  static const double duelFarTop = 0.14;
  static const double duelFarBottom = 0.56;

  /// Near fighter: left half and slightly larger. Right edge at 0.58
  /// keeps the shared strip under a tenth of the width.
  static const double duelNearRight = 0.58;
  static const double duelNearTop = 0.34;

  /// Full-body 2:3 cut-outs must overflow their slot. Fitting them is
  /// what turned a person into a figurine with its feet showing.
  static const double figureOverflow = 1.42;
  static const double figureAspect = 2 / 3;

  /// Letter on a standard, as a fraction of the cloth's short side.
  /// A point size written against the screen made one initial a poster.
  static const double standardLetter = 0.36;

  /// Cloth must read as hanging fabric on a bright arena, not a sheet
  /// of grey glass. The previous fade ended at 0.06 and vanished.
  static const double standardTop = 0.84;
  static const double standardBottom = 0.62;

  static const double plateHeight = 28;
  static const double platePadX = 22;
  static const double plateInset = 18;
  static const double plateGap = 8;
  static const double plateRadius = 2;
  static const double flourish = 7;

  /// A fifth to a quarter of the frame. Growing past this is how a
  /// letter ate the painting it was meant to sit on.
  static const double panelHeightMin = 0.20;
  static const double panelHeightMax = 0.26;

  /// Hard ceiling once the keys are up, so the field scrolls instead of
  /// covering the speaker.
  static const double panelHeightCeiling = 0.48;

  static const double panelRadius = 6;
  static const double panelPadX = 18;
  static const double panelPadY = 16;
  static const double panelShadowBlur = 26;

  /// Equal gutter so the reading panel is not a floating island with a
  /// hole on one side. The skip sits above it, not beside it.
  static const double panelGutter = 10;
  static const double panelStripGap = 6;

  static const double bubbleRadius = 12;
  static const double bubbleMaxWidth = 260;
  static const double bubbleTail = 10;

  static const double avatarSize = 48;
  static const double avatarRing = 2.2;

  /// Both strips share this body. Adding the safe inset only on the
  /// outer edge is what keeps them mirrors of each other.
  static const double meterExtent = 78;
  static const double meterBody = 62;
  static const double meterBarHeight = 7;
  static const double meterPad = 12;
  static const double meterInner = 8;
  static const double meterBarGap = 6;

  static const double inscriptionPadX = 14;
  static const double inscriptionPadY = 8;
  static const double inscriptionRule = 2.5;
  static const double inscriptionFill = 0.55;
  static const double inscriptionHeight = 52;

  static const double skipSize = 52;
  static const double skipGlyph = 26;

  /// The word under the glyph needs two lines and the descenders of the
  /// second. Sizing this band to the glyph alone overflowed it and clipped
  /// the label to its first word.
  static const double skipColumn = 92;
  static const double skipExtent = 96;

  static const double floatSize = 52;
  static const double floatAlarm = 36;
  static const double advanceGlyph = 26;

  /// A shift measured against the fighter's own slot stays restrained on
  /// tablets and phones. Larger travel turns a painted exchange into a bounce.
  static const double duelLunge = 0.035;
  static const double duelRecoil = 7;

  static const double choiceMinHeight = 54;
  static const double choiceRadius = 5;
  static const double choiceRule = 3;
  static const double choiceRuleHeight = 30;
  static const double choicePadX = 14;
  static const double choicePadY = 12;
  static const double choiceGlyph = 22;

  static const Duration flash = Duration(milliseconds: 160);
  static const Duration rise = Duration(milliseconds: 900);
  static const Duration pulse = Duration(milliseconds: 1100);
  static const Duration step = Duration(milliseconds: 260);

  /// Panel height is the copy it holds, then clamped. Using the max
  /// fraction as a floor is how an empty meeting became a third of
  /// the screen.
  /// What a reading panel costs beyond its prose: the paper's own padding,
  /// and the row with the chevron in it. Estimating the prose alone is what
  /// left the last line and the chevron hanging 16 pixels past the paper.
  static const double panelChrome = panelPadY * 2 + 30;

  static double panelHeightFor({
    required double screenHeight,
    required double needed,
    required double keys,
    required bool composing,
  }) {
    final floor = composing ? 148.0 : screenHeight * panelHeightMin;
    final ceiling = math.max(floor, screenHeight - keys - 88);
    final cap = composing
        ? math.min(ceiling, screenHeight * panelHeightCeiling)
        : math.min(ceiling, screenHeight * panelHeightMax);
    return needed.clamp(floor, cap);
  }

  /// Speaker slot hugging one edge. A full-bleed Align is what sat
  /// the cut-out in the middle and then clipped it to empty canvas.
  static Rect speakRect(Size size, StageSide side) {
    final width = size.width * figureSpeak;
    return Rect.fromLTWH(
      side == StageSide.left ? 0 : size.width - width,
      0,
      width,
      size.height,
    );
  }

  /// Two people, one edge each. Speak-width on both sides is what
  /// left no painting between them.
  static Rect pairRect(Size size, StageSide side) {
    final width = size.width * figureRoomPair;
    return Rect.fromLTWH(
      side == StageSide.left ? 0 : size.width - width,
      0,
      width,
      size.height,
    );
  }

  /// Decode height for a speak-rise cut-out in [slotHeight]. A shorter
  /// shelf is how a warmed face painted as a blur the room would not
  /// own.
  static int figureCacheHeight(
    BuildContext context, {
    required double slotHeight,
  }) {
    return (slotHeight *
            figureOverflow *
            MediaQuery.devicePixelRatioOf(context))
        .round();
  }

  /// What the scene parchment actually keeps at the foot. Guessing a
  /// quarter against a petition, or two thirds against a short scene,
  /// is how a face ended up in the paper.
  static double roomReservedHeight({
    required double screenHeight,
    required bool petition,
  }) {
    final fraction = petition ? roomPanelCeiling : panelHeightMax;
    return screenHeight * fraction + roomPanelFoot;
  }

  /// How tall a standing slot may be above that parchment. The full
  /// frame is how a conversation already stands; using it under a
  /// petition is how a head was read through the paper.
  static double roomSlotHeight({
    required double screenHeight,
    required double reservedPanelHeight,
  }) {
    final band = screenHeight - reservedPanelHeight;
    if (band <= 0) return screenHeight * panelHeightMin;
    final storyBand = screenHeight * panelHeightMax + roomPanelFoot;
    if (reservedPanelHeight <= storyBand) return screenHeight;
    return band;
  }
}

/// Which edge a figure, a plate or a tail belongs to.
enum StageSide { left, right }

/// Where a figure stands in the depth of the painting.
enum StageRise {
  /// Half-body speaker, cropped by the bottom edge.
  speak,

  /// Further from the camera, in the upper half.
  far,

  /// Closer to the camera, in the lower half.
  near,
}

/// Where the name ribbon is seated.
enum StagePlateSeat {
  /// Directly beneath a figure's feet.
  feet,

  /// Overlapping the upper edge of a parchment panel.
  panel,
}

/// Which end of the sand a status strip belongs to.
enum StageMeterSeat {
  /// Opponent — pinned to the top, medallion on the right.
  far,

  /// Champion — pinned to the bottom, medallion on the left.
  near,
}

/// How heavily the painting is lowered so figures can stand in it.
enum StageVeil {
  /// Arena: dark tiers, lit sand.
  arena,

  /// Room: only the parchment's band, so a speaker is still a person.
  room,
}

/// Every reserved band on the sand, in pixels, from one set of fractions.
///
/// Composing from Align and Row is how both fighters landed in the
/// same half. The widgets only consume these rects.
@immutable
class StageDuelLayout {
  factory StageDuelLayout.of(
    BuildContext context, {
    required double panelHeight,
  }) {
    return StageDuelLayout._(
      size: MediaQuery.sizeOf(context),
      padding: MediaQuery.paddingOf(context),
      panelHeight: panelHeight,
    );
  }

  const StageDuelLayout._({
    required this.size,
    required this.padding,
    required this.panelHeight,
  });

  final Size size;
  final EdgeInsets padding;
  final double panelHeight;

  double get _w => size.width;
  double get _h => size.height;

  double get topStripHeight => padding.top + StageMeasure.meterExtent;
  double get nearStripHeight => padding.bottom + StageMeasure.meterExtent;

  Rect get topStrip => Rect.fromLTWH(0, 0, _w, topStripHeight);
  Rect get nearStrip =>
      Rect.fromLTWH(0, _h - nearStripHeight, _w, nearStripHeight);

  Rect get question {
    final top = topStripHeight;
    return Rect.fromLTWH(
      StageMeasure.panelGutter,
      top,
      _w - StageMeasure.panelGutter * 2,
      StageMeasure.inscriptionHeight,
    );
  }

  /// Reading panel, full width minus equal gutters, sitting on the
  /// near strip. Leaving a hole on one side for the skip is how it
  /// became a floating island.
  Rect get panel {
    final height = panelHeight;
    final top = nearStrip.top - StageMeasure.panelStripGap - height;
    return Rect.fromLTWH(
      StageMeasure.panelGutter,
      top,
      _w - StageMeasure.panelGutter * 2,
      height,
    );
  }

  /// Skip sits above the panel on the right, not beside it. Beside it
  /// stole a fifth of the page and hid the far plate's trailing letters.
  Rect get skip {
    final width = StageMeasure.skipColumn;
    final height = StageMeasure.skipExtent;
    final right = _w - StageMeasure.panelGutter;
    final bottom = panel.top - StageMeasure.plateGap;
    return Rect.fromLTRB(right - width, bottom - height, right, bottom);
  }

  Rect get farFigure {
    final questionBottom = question.bottom;
    var top = _h * StageMeasure.duelFarTop;
    // A short screen pushes the strip into the 14% band. Crossing the
    // inscription is the second cream-on-fighter failure.
    if (top < questionBottom + StageMeasure.plateGap) {
      top = questionBottom + StageMeasure.plateGap;
    }
    return Rect.fromLTRB(
      _w * StageMeasure.duelFarLeft,
      top,
      _w,
      _h * StageMeasure.duelFarBottom,
    );
  }

  Rect get nearFigure {
    final plateTop =
        panel.top - StageMeasure.plateGap - StageMeasure.plateHeight;
    var top = _h * StageMeasure.duelNearTop;
    if (top < question.bottom + StageMeasure.plateGap) {
      top = question.bottom + StageMeasure.plateGap;
    }
    var bottom = plateTop - StageMeasure.plateGap;
    if (bottom <= top) {
      bottom = top + 8;
    }
    return Rect.fromLTRB(0, top, _w * StageMeasure.duelNearRight, bottom);
  }

  /// Plate band under a fighter, centred on that fighter, then clamped
  /// so a long name cannot walk off the screen or under the panel.
  Rect plateUnder(Rect fighter, {double reserveRight = 0}) {
    final top = fighter.bottom + StageMeasure.plateGap;
    final maxTop = panel.top - StageMeasure.plateHeight - StageMeasure.plateGap;
    final clampedTop = math.min(top, maxTop);
    var left = fighter.left;
    var width = fighter.width;
    final inset = StageMeasure.plateInset;
    if (left < inset) {
      width -= inset - left;
      left = inset;
    }
    final rightLimit = _w - inset - reserveRight;
    if (left + width > rightLimit) {
      width = rightLimit - left;
    }
    width = math.max(width, 8);
    return Rect.fromLTWH(
      left,
      clampedTop.clamp(0.0, _h - StageMeasure.plateHeight),
      width,
      StageMeasure.plateHeight,
    );
  }

  /// The skip begins beneath this band. Reserving its width here reduced a
  /// fighter's full name to four letters even though the controls never meet.
  Rect get farPlate => plateUnder(farFigure);
  Rect get nearPlate => plateUnder(nearFigure);
}

/// Where each person stands in a room, from the parchment's reserved
/// band and how many are actually there.
///
/// Align in a full-bleed Stack is what sat two people on the same
/// spot. The widgets only consume these rects.
@immutable
class StageRoomLayout {
  factory StageRoomLayout.of(
    BuildContext context, {
    required int count,
    required double reservedPanelHeight,
  }) {
    return StageRoomLayout._(
      size: MediaQuery.sizeOf(context),
      count: count,
      reservedPanelHeight: reservedPanelHeight,
    );
  }

  const StageRoomLayout._({
    required this.size,
    required this.count,
    required this.reservedPanelHeight,
  });

  final Size size;
  final int count;
  final double reservedPanelHeight;

  double get slotHeight {
    final standing = StageMeasure.roomSlotHeight(
      screenHeight: size.height,
      reservedPanelHeight: reservedPanelHeight,
    );
    if (count < 3) return standing;
    // One speak slot shared three ways is a skyline of heads.
    // The row is sized to the free band so they stand on the
    // parchment and stay cropped by it.
    final band = size.height - reservedPanelHeight;
    return band > 0 ? band : standing;
  }

  /// A Size whose height is the standing slot. Passing the screen
  /// itself to speakRect under a petition is the face-in-the-paper
  /// failure; this is the same width against the band they may use.
  Size get _slotSize => Size(size.width, slotHeight);

  /// The row cannot share the speak slot. Below this they overflow
  /// the frame and must scroll, or the last head is untappable.
  bool get crowdFits => count * StageMeasure.figureRoomCrowd <= 1;

  StageSide sideAt(int index) {
    if (count <= 1) return StageSide.left;
    if (count == 2) {
      return index == 0 ? StageSide.left : StageSide.right;
    }
    return index < count / 2 ? StageSide.left : StageSide.right;
  }

  Rect figureAt(int index) {
    if (count <= 1) {
      return StageMeasure.speakRect(_slotSize, StageSide.left);
    }
    if (count == 2) {
      return StageMeasure.pairRect(
        _slotSize,
        index == 0 ? StageSide.left : StageSide.right,
      );
    }
    final width = size.width * StageMeasure.figureRoomCrowd;
    if (crowdFits) {
      final span = size.width - width;
      final left = span * (index / (count - 1));
      return Rect.fromLTWH(left, 0, width, slotHeight);
    }
    return Rect.fromLTWH(index * width, 0, width, slotHeight);
  }
}
