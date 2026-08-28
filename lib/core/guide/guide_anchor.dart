import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The geometry the guide should cut, discovered from the target itself.
///
/// [rect] is the box actually painted — not necessarily the anchor's own box,
/// since an anchor usually wraps a widget that paints inside it. [radius] is
/// that widget's own corner radius, so the opening matches the control rather
/// than approximating it, and [isOval] marks the targets that are drawn as
/// ellipses rather than rounded rectangles.
@immutable
class GuideTarget {
  final Rect rect;
  final BorderRadius? radius;
  final bool isOval;

  const GuideTarget({required this.rect, this.radius, this.isOval = false});

  GuideTarget withRect(Rect value) =>
      GuideTarget(rect: value, radius: radius, isOval: isOval);

  @override
  bool operator ==(Object other) =>
      other is GuideTarget &&
      other.rect == rect &&
      other.radius == radius &&
      other.isOval == isOval;

  @override
  int get hashCode => Object.hash(rect, radius, isOval);
}

/// What a target actually looks like on screen.
///
/// Discovered once per anchor and then re-read from the live render boxes on
/// every frame, so the opening tracks scrolling and layout without walking the
/// element tree again.
class _Measured {
  /// The single descendant that stands for the whole target, when there is
  /// one — a button's own decorated box, a card, a chip.
  final RenderBox? outline;
  final BorderRadius? outlineRadius;
  final bool outlineIsOval;

  /// Every descendant that actually puts ink on screen. Their union is the
  /// tight silhouette of a group that has no single outline of its own — a row
  /// of chips, a pair of toggle pills, a column of settings.
  final List<RenderBox> ink;

  /// Largest corner radius among the group's painted parts, so the opening
  /// round a pair of r=12 pills is r=12 rather than a guessed default.
  final double groupRadius;

  /// Size of the anchor when this was measured. A different one means the
  /// subtree is not what it was — content arrived, a row wrapped, the keyboard
  /// reflowed it — and the cached boxes describe a shape that is no longer
  /// there. Cheaper than re-walking every frame, and it catches the case that
  /// actually bites: an anchor that was still empty when the beat opened.
  final Size measuredAt;

  const _Measured({
    required this.outline,
    required this.outlineRadius,
    required this.outlineIsOval,
    required this.ink,
    required this.groupRadius,
    required this.measuredAt,
  });

  static bool _usable(RenderBox box) =>
      box.attached && box.hasSize && !box.size.isEmpty;

  bool isStaleFor(Rect anchorRect) {
    if (anchorRect.size != measuredAt) return true;
    // Nothing recognisable was found last time. Keep looking rather than
    // caching the miss forever — a lazily built card, an image that has not
    // decoded yet, and a list still filling all measure as empty at first.
    if (outline == null && ink.isEmpty) return true;
    final own = outline;
    if (own != null && !_usable(own)) return true;
    for (final box in ink) {
      if (!_usable(box)) return true;
    }
    return false;
  }
}

/// Screen rectangles for guide targets, keyed by stable string id.
///
/// A registry rather than a widget-tree lookup because the guide overlay lives
/// above the Navigator (see `GuideHost`) while its targets sit deep inside
/// routes and modal sheets — there is no shared ancestor to inherit from.
///
/// The trade this buys: `play_screen.dart` is four thousand lines and knows
/// nothing about the guide. Marking a target is one wrap, and the sequencing
/// lives entirely in `guide_flows.dart`.
class GuideAnchorRegistry {
  GuideAnchorRegistry._();
  static final instance = GuideAnchorRegistry._();

  final Map<String, GlobalKey> _anchors = {};

  /// The route each anchor lives on, so a target buried under a dialog or a
  /// sheet can be told apart from one the player is actually looking at.
  final Map<String, ModalRoute<dynamic>?> _routes = {};

  /// Discovered geometry, keyed by anchor id. Walking the element tree on
  /// every frame would be wasteful; the render boxes it finds are stable, so
  /// only their rects are re-read.
  final Map<String, _Measured> _shapes = {};

  /// How much of a target has to be on screen before it counts as visible.
  /// Enough that the opening lands on the thing it names, loose enough that a
  /// card tucked under a translucent bar still resolves.
  static const _minVisible = 0.75;

  void register(String id, GlobalKey key) {
    _anchors[id] = key;
    _shapes.remove(id);
  }

  /// Bind the anchor's route, once it is known. Called from
  /// `didChangeDependencies`, which is the only place `ModalRoute.of` may be
  /// read — doing it per frame from the resolver would make every anchor
  /// depend on route status and rebuild on every push.
  void bindRoute(String id, GlobalKey key, ModalRoute<dynamic>? route) {
    if (_anchors[id] != key) return;
    _routes[id] = route;
    // `ModalRoute.of` makes the anchor depend on its route's status, so this
    // runs again the moment something is pushed over the surface or popped
    // off it. That is the only notice the controller gets that a sheet has
    // closed, since a `showModalBottomSheet` never touches the router.
    onSurfaceChanged?.call();
  }

  /// Told when an anchor's route status changes. See [bindRoute].
  VoidCallback? onSurfaceChanged;

  /// Whether any of [ids] is in the tree but sitting under something else.
  ///
  /// Opening an arc over a sheet the player is being asked to answer is the
  /// worst thing the guide can do: the scrim covers the sheet's own buttons,
  /// so the tip has to be dismissed before the question underneath it can be.
  bool isCovered(List<String> ids) {
    for (final id in ids) {
      if (_anchors.containsKey(id) && _isBuried(id)) return true;
    }
    return false;
  }

  /// Drop the entry only if it still points at this key — a route transition
  /// can mount the next screen's anchor before the old one disposes, and the
  /// straggler must not delete the live registration.
  void unregister(String id, GlobalKey key) {
    if (_anchors[id] != key) return;
    _anchors.remove(id);
    _routes.remove(id);
    _shapes.remove(id);
  }

  /// The shape to cut for [id]: the tight silhouette of what the anchor
  /// actually paints, with that content's own corner radius.
  ///
  /// An anchor almost never hugs its content — it wraps a `Padding`, a
  /// `SizedBox` taller than the row inside it, a horizontal list whose items
  /// are inset from both edges. Cutting the anchor's own box is what made
  /// openings read as a loose rectangle floating around the control rather
  /// than the control itself lit up, so the box is tightened to the ink before
  /// anything else happens.
  ///
  /// Order of preference:
  ///  1. a descendant that stands for the whole target — its outline, exactly;
  ///  2. the union of everything the anchor paints, with the group's radius;
  ///  3. the anchor's own box, when it paints nothing we recognise.
  GuideTarget? targetOf(String id) {
    final anchorRect = resolve(id);
    if (anchorRect == null) return null;

    var measured = _shapes[id];
    if (measured != null && measured.isStaleFor(anchorRect)) {
      _shapes.remove(id);
      measured = null;
    }
    measured ??= _measure(id, anchorRect);
    if (measured == null) return GuideTarget(rect: anchorRect);

    final own = measured.outline;
    if (own != null) {
      return GuideTarget(
        rect: own.localToGlobal(Offset.zero) & own.size,
        radius: measured.outlineRadius,
        isOval: measured.outlineIsOval,
      );
    }

    final content = _union(measured.ink, anchorRect);
    if (content == null || _isDetail(content, anchorRect)) {
      return GuideTarget(rect: anchorRect);
    }
    return GuideTarget(
      rect: content,
      radius: measured.groupRadius > 0
          ? BorderRadius.circular(measured.groupRadius)
          : null,
    );
  }

  /// Whether the ink is a small detail floating inside a much larger anchor
  /// rather than the anchor's content.
  ///
  /// The case this exists for: a bare glyph inside a 44pt tap target. Cutting
  /// to the glyph would light something smaller than the control the player
  /// has to press, which is worse than a little slack. It has to be small on
  /// *both* axes to count — a padded row of pills is 88% wide and 71% tall,
  /// and that one genuinely wants tightening.
  static bool _isDetail(Rect content, Rect anchor) {
    if (anchor.width <= 0 || anchor.height <= 0) return false;
    return content.width < anchor.width * 0.6 &&
        content.height < anchor.height * 0.6;
  }

  /// Union of [boxes] clipped to [bounds].
  ///
  /// The clip is not cosmetic: a horizontal list keeps a dozen items laid out
  /// beyond its own viewport, and unioning those would stretch the opening far
  /// off the side of the screen.
  static Rect? _union(List<RenderBox> boxes, Rect bounds) {
    Rect? total;
    for (final box in boxes) {
      if (!_Measured._usable(box)) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (!rect.overlaps(bounds)) continue;
      final clipped = rect.intersect(bounds);
      if (clipped.width <= 0 || clipped.height <= 0) continue;
      total = total == null ? clipped : total.expandToInclude(clipped);
    }
    if (total == null || total.width <= 0 || total.height <= 0) return null;
    return total;
  }

  /// Walk down from the anchor, collecting what it paints and any outline that
  /// stands for the whole of it.
  ///
  /// Bounded on purpose: this runs off a frame callback, and an unbounded walk
  /// through a deep subtree would cost more than the precision is worth. The
  /// result is cached, so the walk happens once per anchor rather than once
  /// per frame.
  _Measured? _measure(String id, Rect anchorRect) {
    final context = _anchors[id]?.currentContext;
    if (context == null) return null;

    final ink = <RenderBox>[];
    final candidates = <(RenderBox, Rect, BorderRadius?, bool)>[];
    var groupRadius = 0.0;
    var budget = 320;

    void visit(Element element) {
      if (budget <= 0) return;
      budget--;

      final object = element.findRenderObject();
      RenderBox? box;
      Rect? rect;
      if (object is RenderBox && _Measured._usable(object)) {
        box = object;
        rect = object.localToGlobal(Offset.zero) & object.size;
        // Laid out but parked outside the anchor entirely: a list's recycled
        // items, a collapsed branch. Nothing inside it can be visible either.
        if (!rect.overlaps(anchorRect)) return;
      }

      final shape = _shapeOfWidget(element.widget);
      if (box != null && rect != null) {
        if (_paintsInk(element.widget)) {
          ink.add(box);
          final declared = shape?.$1;
          if (declared != null) {
            // Capped at what the part could actually be drawn with — a stadium
            // declares an effectively infinite radius, and letting that win
            // would round every group off into a pill.
            groupRadius = math.max(
              groupRadius,
              math.min(_maxCorner(declared), rect.shortestSide / 2),
            );
          }
        }
        if (shape != null) {
          candidates.add((box, rect, shape.$1, shape.$2));
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);

    // The outline has to stand for the *content*, not for the anchor. A
    // control inside 16pt of padding is 70% of its anchor but 100% of the ink,
    // and one of two toggle pills is 100% of neither.
    final content = _union(ink, anchorRect) ?? anchorRect;
    RenderBox? outline;
    BorderRadius? outlineRadius;
    var outlineIsOval = false;
    var tightest = double.infinity;
    var tightestShape = -1;
    for (final (box, rect, radius, isOval) in candidates) {
      if (!_standsFor(rect, content)) continue;
      final area = rect.width * rect.height;
      final specificity = _specificityOf(radius, isOval);
      // Smallest wins: an `InkWell` and the `DecoratedBox` it wraps report the
      // same shape, and the inner one is the outline actually painted.
      //
      // Ties are broken on how much the candidate actually says. A circular
      // button reports the same box three times over — its ink well, its
      // decoration, and whatever wraps them — and only some of those know it
      // is round. Leaving that to traversal order means the vaguest answer
      // usually wins, because the vaguest widget is usually the outermost.
      final better =
          area < tightest || (area == tightest && specificity > tightestShape);
      if (better) {
        tightest = area;
        tightestShape = specificity;
        outline = box;
        outlineRadius = radius;
        outlineIsOval = isOval;
      }
    }

    final measured = _Measured(
      outline: outline,
      outlineRadius: outlineRadius,
      outlineIsOval: outlineIsOval,
      ink: ink,
      groupRadius: groupRadius,
      measuredAt: anchorRect.size,
    );
    _shapes[id] = measured;
    return measured;
  }

  /// How much a candidate's declared shape actually tells us, for tie-breaks.
  ///
  /// An oval is the most specific thing a widget can say about itself; a real
  /// corner radius is next; a bare square-cornered rectangle says the least,
  /// and is what a wrapper reports when it is only there to clip.
  static int _specificityOf(BorderRadius? radius, bool isOval) {
    if (isOval) return 2;
    if (radius != null && _maxCorner(radius) > 0) return 1;
    return 0;
  }

  static double _maxCorner(BorderRadius radius) => math.max(
    math.max(radius.topLeft.x, radius.topRight.x),
    math.max(radius.bottomLeft.x, radius.bottomRight.x),
  );

  /// Whether [candidate] is close enough to [content] to be treated as the
  /// target's own silhouette rather than a detail inside it.
  ///
  /// Both dimensions have to hold. One chip in a row of six fails on width; a
  /// single passage inside the story column fails on height; a control sitting
  /// inside its own padding passes, which is the case worth catching.
  static bool _standsFor(Rect candidate, Rect content) {
    if (content.width <= 0 || content.height <= 0) return false;
    return candidate.width >= content.width * 0.9 &&
        candidate.height >= content.height * 0.9;
  }

  /// Whether a widget puts anything on screen of its own.
  ///
  /// Only these count towards the tight silhouette. Layout widgets — padding,
  /// rows, sized boxes, alignment — are exactly what the opening is meant to
  /// stop cutting around, and an `InkWell` is a hit area rather than ink.
  static bool _paintsInk(Widget widget) {
    switch (widget) {
      case RichText():
      case Icon():
      case ImageIcon():
      case Image():
      case CustomPaint():
      case ClipRRect():
      case ClipOval():
      case ClipPath():
      case Card():
        return true;
      // A `Material` with no shape of its own builds one of these to host its
      // clip and its shadow. At elevation 0 over a transparent colour it puts
      // nothing on screen, and counting it as ink would let a bare rectangle
      // stand in for whatever the control actually paints.
      case PhysicalModel(:final color, :final elevation):
        return elevation > 0 || color.a > 0;
      case Material(:final color, :final elevation, :final type):
        if (type == MaterialType.transparency) return false;
        return elevation > 0 || (color != null && color.a > 0);
      case DecoratedBox(:final decoration):
        return _decorationPaints(decoration);
      // `Ink` paints its decoration into the enclosing Material's ink layer
      // rather than through a DecoratedBox, so nothing below it reports the
      // box that is actually on screen. Without this the union stopped at the
      // label inside and the opening floated loose around the control.
      case Ink(:final decoration):
        return decoration != null && _decorationPaints(decoration);
      default:
        return false;
    }
  }

  static bool _decorationPaints(Decoration decoration) {
    if (decoration is BoxDecoration) {
      return (decoration.color != null && decoration.color!.a > 0) ||
          decoration.gradient != null ||
          decoration.image != null ||
          decoration.border != null ||
          (decoration.boxShadow?.isNotEmpty ?? false);
    }
    if (decoration is ShapeDecoration) {
      return (decoration.color != null && decoration.color!.a > 0) ||
          decoration.gradient != null ||
          decoration.image != null;
    }
    return true;
  }

  /// The corner radius a widget declares, and whether it is drawn as an oval.
  ///
  /// Deliberately reads the widgets that carry the radius rather than guessing
  /// from the render tree: an `InkWell`'s `borderRadius` never becomes a clip,
  /// so the render objects alone cannot tell you that the narration marker is
  /// rounded down its left side only.
  static (BorderRadius?, bool)? _shapeOfWidget(Widget widget) {
    BorderRadius? resolve(BorderRadiusGeometry? geometry) =>
        geometry?.resolve(TextDirection.ltr);

    (BorderRadius?, bool)? fromBorder(ShapeBorder? border) {
      if (border is RoundedRectangleBorder) {
        return (resolve(border.borderRadius), false);
      }
      if (border is ContinuousRectangleBorder) {
        return (resolve(border.borderRadius), false);
      }
      // A stadium is a rounded rectangle with the largest radius that fits;
      // the hole builder clamps it to half the shorter side.
      if (border is StadiumBorder) {
        return (BorderRadius.circular(double.maxFinite), false);
      }
      if (border is CircleBorder) return (null, true);
      return null;
    }

    switch (widget) {
      case ClipRRect(:final borderRadius):
        return (resolve(borderRadius), false);
      case ClipOval():
        return (null, true);
      // See `_paintsInk`: an invisible `PhysicalModel` is `Material`'s internal
      // clip host, not a shape anybody declared. It reports a square-cornered
      // rectangle the exact size of the control inside it, so letting it count
      // as an outline is what put a rounded *box* around the circular world
      // actions button instead of lighting the circle.
      case PhysicalModel(
        :final borderRadius,
        :final shape,
        :final color,
        :final elevation,
      ):
        if (elevation <= 0 && color.a == 0) return null;
        return (resolve(borderRadius), shape == BoxShape.circle);
      case Material(:final borderRadius, :final shape):
        if (shape != null) return fromBorder(shape);
        if (borderRadius != null) return (resolve(borderRadius), false);
        return null;
      case Card(:final shape):
        return fromBorder(shape);
      case InkWell(:final borderRadius, :final customBorder):
        if (customBorder != null) return fromBorder(customBorder);
        if (borderRadius != null) return (resolve(borderRadius), false);
        return null;
      case InkResponse(:final borderRadius, :final customBorder):
        if (customBorder != null) return fromBorder(customBorder);
        if (borderRadius != null) return (resolve(borderRadius), false);
        return null;
      case Ink(:final decoration):
        if (decoration is BoxDecoration) {
          if (decoration.shape == BoxShape.circle) return (null, true);
          final radius = resolve(decoration.borderRadius);
          if (radius != null) return (radius, false);
          return (BorderRadius.zero, false);
        }
        if (decoration is ShapeDecoration) return fromBorder(decoration.shape);
        return null;
      case DecoratedBox(:final decoration):
        if (decoration is BoxDecoration) {
          if (decoration.shape == BoxShape.circle) return (null, true);
          final radius = resolve(decoration.borderRadius);
          if (radius != null) return (radius, false);
          // A square-cornered painted box is still the target's own outline.
          return (BorderRadius.zero, false);
        }
        if (decoration is ShapeDecoration) return fromBorder(decoration.shape);
        return null;
      default:
        return null;
    }
  }

  bool has(String id) => resolve(id) != null;

  /// First of [ids] that is on screen right now, or null.
  String? firstResolvable(List<String> ids) {
    for (final id in ids) {
      if (resolve(id) != null) return id;
    }
    return null;
  }

  /// First of [ids] that is in the tree, on screen or not, or null.
  String? firstMounted(List<String> ids) {
    for (final id in ids) {
      if (isMounted(id)) return id;
    }
    return null;
  }

  /// Whether [id] is in the tree and laid out, regardless of whether it is
  /// currently on screen. Distinguishes "scrolled away" (worth scrolling to)
  /// from "not there at all" (worth dropping the beat).
  bool isMounted(String id) {
    if (_isBuried(id)) return false;
    final object = _anchors[id]?.currentContext?.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize;
  }

  /// Whether something has been pushed over the anchor's route.
  ///
  /// A dialog, a modal sheet, or a pushed page leaves the anchor underneath it
  /// laid out and perfectly resolvable — nothing about its rect says it is no
  /// longer the thing on screen. Spotlighting it anyway drops the scrim on top
  /// of whatever the player just opened and swallows every tap they make at
  /// it, which is the worst friction the guide is capable of causing. Treating
  /// the target as gone hands it to the beat watchdog, which ends the arc.
  bool _isBuried(String id) {
    final route = _routes[id];
    return route != null && !route.isCurrent;
  }

  /// Whether [id] resolves but still runs off an edge of the screen.
  ///
  /// A target can be three-quarters visible — enough to resolve — and still be
  /// larger than the room left for it, which is what made the realm's four
  /// tomes read as a box running off the bottom rather than as a lit group.
  /// Answering true sends it through [ensureVisible] first.
  ///
  /// Measured on the axis the target can actually be moved along. This only
  /// looked at top and bottom, so the Chronicle's tab strip — which scrolls
  /// sideways — never scrolled at all: a tab hanging off the right edge was
  /// visible enough to resolve, so the beat opened on it as it stood and the
  /// opening was clipped flat against the bezel. Checking the horizontal edges
  /// unconditionally would be worse, though: a full-width card in a vertical
  /// list overhangs by design, and "fixing" that would scroll the page
  /// sideways-or-worse for no reason a reader could see.
  bool overflowsViewport(String id) {
    final rect = resolve(id);
    if (rect == null) return false;
    final context = _anchors[id]?.currentContext;
    if (context == null) return false;
    final view = View.maybeOf(context);
    if (view == null) return false;
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    if (Scrollable.maybeOf(context)?.position.axis == Axis.horizontal) {
      return rect.left < screen.left || rect.right > screen.right;
    }
    return rect.top < screen.top || rect.bottom > screen.bottom;
  }

  /// Bring [id] into view when it sits inside a scrollable.
  ///
  /// Without this, an arc through a long sheet — Scene Settings, the Chronicle,
  /// the realm's tomes — would silently drop every beat below the fold.
  Future<void> ensureVisible(String id) async {
    final context = _anchors[id]?.currentContext;
    final scrollable = context == null ? null : Scrollable.maybeOf(context);
    if (context == null || scrollable == null) return;
    // Sideways strips — the Chronicle's tabs — read best centred; a tab pulled
    // to the third of a narrow strip lands half off the edge and drags the
    // spotlight with it. Vertical sheets keep the target high so the card has
    // somewhere to sit underneath.
    final horizontal = scrollable.position.axis == Axis.horizontal;
    // A target that fills most of the screen has to start at the top or it
    // cannot fit at all; 0.35 would push its tail straight back off the
    // bottom. Shorter targets keep the third-down placement, which leaves the
    // card somewhere to sit underneath.
    final box = context.findRenderObject();
    final tall =
        !horizontal &&
        box is RenderBox &&
        box.hasSize &&
        box.size.height > scrollable.position.viewportDimension * 0.5;
    await Scrollable.ensureVisible(
      context,
      alignment: horizontal
          ? 0.5
          : tall
          ? 0.02
          : 0.35,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Global rect of [id], or null when the target is gone, unlaid, collapsed,
  /// or scrolled off screen.
  ///
  /// Null is a normal answer, not a failure: an empty bond rail or a world
  /// without stats simply has nothing to point at, and the controller either
  /// degrades the beat to a floating card or drops it.
  Rect? resolve(String id) {
    if (_isBuried(id)) return null;
    final key = _anchors[id];
    final context = key?.currentContext;
    if (context == null) return null;

    final object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    if (object.size.isEmpty) return null;

    final view = View.maybeOf(context);
    if (view == null) return null;
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);

    final origin = object.localToGlobal(Offset.zero);
    final rect = origin & object.size;
    // A target scrolled out of view, or belonging to an inactive shell branch,
    // must not be spotlit — a hole over nothing reads as a bug.
    if (!rect.overlaps(screen)) return null;
    // Nor may a target that is only *just* in view. A tall card scrolled three
    // quarters out is still resolvable by rect, and spotlighting it puts the
    // opening half off the screen — where it gets clamped back inside and ends
    // up sitting over content that is not the target at all. Answering null
    // hands it to the controller, which scrolls it properly into view first.
    final visible = rect.intersect(screen);
    if (visible.width < math.min(rect.width, screen.width) * _minVisible ||
        visible.height < math.min(rect.height, screen.height) * _minVisible) {
      return null;
    }
    return rect;
  }
}

/// Marks a widget as a guide target. One line at the call site, no refactor.
///
/// ```dart
/// GuideAnchor(id: GuideIds.playChoices, child: ChoiceChips(...))
/// ```
///
/// Adds no layout, no paint, and no hit-test behaviour of its own.
class GuideAnchor extends StatefulWidget {
  final String id;
  final Widget child;

  const GuideAnchor({super.key, required this.id, required this.child});

  @override
  State<GuideAnchor> createState() => _GuideAnchorState();
}

class _GuideAnchorState extends State<GuideAnchor> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    GuideAnchorRegistry.instance.register(widget.id, _key);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    GuideAnchorRegistry.instance.bindRoute(
      widget.id,
      _key,
      ModalRoute.of(context),
    );
  }

  @override
  void didUpdateWidget(GuideAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      GuideAnchorRegistry.instance.unregister(oldWidget.id, _key);
      GuideAnchorRegistry.instance.register(widget.id, _key);
      GuideAnchorRegistry.instance.bindRoute(
        widget.id,
        _key,
        ModalRoute.of(context),
      );
    }
  }

  @override
  void dispose() {
    GuideAnchorRegistry.instance.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

/// Anchor [child] only when [condition] holds.
///
/// For repeated widgets where exactly one instance should be the target — the
/// first card in a list stands for "a world", not for that particular world.
Widget guideAnchorIf(bool condition, String id, Widget child) =>
    condition ? GuideAnchor(id: id, child: child) : child;
