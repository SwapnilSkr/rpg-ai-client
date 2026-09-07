import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../domain/interactive_world.dart';
class _FogPainter extends CustomPainter {
  const _FogPainter({
    required this.fog,
    required this.clearings,
    required this.radius,
  });

  final ui.Image? fog;
  final List<Offset> clearings;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    // Tiles are drawn smaller than the source so a cloud stays a cloud when the
    // player zooms in; at 1:1 a single tile blankets half a phone screen.
    final shader = fog == null
        ? null
        : ImageShader(
            fog!,
            TileMode.repeated,
            TileMode.repeated,
            (Matrix4.identity()..scaleByDouble(.55, .55, 1, 1)).storage,
          );
    canvas.saveLayer(bounds, Paint());
    // The flat tint is what actually hides the land. It is drawn first and
    // always, so the map's legibility does not depend on the texture existing.
    canvas.drawRect(bounds, Paint()..color = _unexplored);
    if (shader != null) {
      // `Paint.color` is IGNORED once a shader is set, so tinting the mist has
      // to happen through a colour filter and an opacity layer. Drawing the
      // texture plainly paints an opaque grey sheet over the whole world.
      canvas.saveLayer(bounds, Paint()..color = const Color(0x80FFFFFF));
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = shader
          // A LIGHT tint, so the texture reads as lit vapour sitting on the
          // land. Multiplying by a dark navy made the cloud darker than the
          // ground it covered, which is not what mist does.
          ..colorFilter = const ColorFilter.mode(
            Color(0xFFD8CFC2),
            BlendMode.multiply,
          ),
      );
      canvas.restore();
    }
    // Soft-edged holes. dstOut removes fog where the player has been told
    // something exists, and the gradient keeps the boundary from reading as a
    // drawn circle.
    final cut = Paint()..blendMode = BlendMode.dstOut;
    for (final centre in clearings) {
      cut.shader = ui.Gradient.radial(centre, radius, const [
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0x00FFFFFF),
      ], const [0.0, 0.55, 1.0]);
      canvas.drawCircle(centre, radius, cut);
    }
    canvas.restore();
  }

  /// Unexplored ground is VEILED, not darkened.
  ///
  /// This was a near-black scrim (0xC2090B10) and it was wrong. Darkening works
  /// only while every plate is a dim forest or a night city; over a bright snow
  /// plate it reads as an underexposed image — as if the art failed to load —
  /// and it buried seven painted settlements the player was meant to sense.
  ///
  /// A pale warm veil hides the same information and reads as weather. The land
  /// stays legible, which is what makes the map feel like somewhere real with
  /// unvisited corners, and the warm cast keeps the world's gold rather than
  /// draining it grey. Swap in a cold grey-blue (0x85A8B2C4) for a colder
  /// genre pack; the structure does not change.
  ///
  /// What stays hidden is the *contents* — a rumoured place is not drawn at
  /// all, and that is the actual secret.
  static const _unexplored = Color(0x80BAB2A8);


  @override
  bool shouldRepaint(covariant _FogPainter old) =>
      old.fog != fog ||
      old.radius != radius ||
      old.clearings.length != clearings.length;
}

class WorldMapView extends StatefulWidget {
  const WorldMapView({
    super.key,
    required this.world,
    required this.state,
    required this.selectedId,
    required this.onSelect,
  });

  final InteractiveWorld world;
  final InteractiveWorldState state;
  final String? selectedId;
  final ValueChanged<WorldLocation> onSelect;

  @override
  State<WorldMapView> createState() => _WorldMapViewState();
}

class _WorldMapViewState extends State<WorldMapView> {
  final _controller = TransformationController();
  ui.Image? _fog;
  Size _canvas = Size.zero;
  bool _framed = false;

  @override
  void initState() {
    super.initState();
    _loadFog();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fog?.dispose();
    super.dispose();
  }

  Future<void> _loadFog() async {
    final url = widget.world.urlFor(widget.world.fogAssetId);
    if (url == null) return;
    final provider = NetworkImage(url);
    final completer = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        provider.resolve(const ImageConfiguration()).removeListener(listener);
      },
      onError: (_, _) {},
    );
    provider.resolve(const ImageConfiguration()).addListener(listener);
    try {
      final image = await completer.future;
      if (mounted) setState(() => _fog = image);
    } catch (_) {
      // No fog texture yet is fine — the painter falls back to flat darkness.
    }
  }

  /// Places the player has heard of. Everything else is not drawn at all.
  List<WorldLocation> get _visible {
    final flags = widget.state.flags;
    return widget.world.locations
        .where(
          (l) =>
              widget.state.revealedIds.contains(l.id) ||
              l.visibilityFor(flags) != WorldVisibility.rumoured,
        )
        .toList()
      ..sort((a, b) => a.sprite.z.compareTo(b.sprite.z));
  }

  /// On-screen size of a marker's tap target, in logical pixels.
  static const _markerHitSize = 52.0;

  /// The tap target for a place.
  ///
  /// A marker is chrome, so its target is a constant size on SCREEN rather than
  /// on the map — dividing by zoom keeps it that way at any magnification. The
  /// sprite branch that used to live here sized a box from the landmark art's
  /// measured aspect; there is no landmark art any more.
  Rect _rectFor(WorldLocation location, Size canvas, {double zoom = 1}) {
    final side = _markerHitSize / (zoom <= 0 ? 1 : zoom);
    return Rect.fromCenter(
      center: Offset(
        location.sprite.x * canvas.width,
        location.sprite.y * canvas.height,
      ),
      width: side,
      height: side,
    );
  }

  /// Zoom the map opens at.
  ///
  /// Fitting the map's full width on screen is the wrong default: it makes a
  /// landmark about 78dp on a phone, so the city reads as texture and the
  /// player cannot tell a place from the painted rooftops around it. The whole
  /// map is several screens tall anyway, so nothing is gained by starting
  /// zoomed out — the player pans regardless. Pinching out to the overview is
  /// still there via minScale.
  static const _openingScale = 2.4;

  /// Centres the viewport on a location, clamped so the camera never leaves the
  /// world. Pass a scale to change zoom; omit it to keep the player's own.
  void _frameOn(String? locationId, Size viewport, {double? atScale}) {
    if (_canvas == Size.zero || viewport.isEmpty) return;
    final target = widget.world.locations
        .where((l) => l.id == locationId)
        .firstOrNull;
    if (target == null) return;
    final scale = atScale ?? _controller.value.getMaxScaleOnAxis();
    final cx = target.sprite.x * _canvas.width * scale;
    final cy = target.sprite.y * _canvas.height * scale;
    final maxX = (_canvas.width * scale - viewport.width).clamp(0.0, double.infinity);
    final maxY = (_canvas.height * scale - viewport.height).clamp(0.0, double.infinity);
    final dx = (cx - viewport.width / 2).clamp(0.0, maxX);
    final dy = (cy - viewport.height / 2).clamp(0.0, maxY);
    _controller.value = Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1)
      ..setTranslationRaw(-dx, -dy, 0);
  }

  void _handleTap(Offset local) {
    if (_canvas == Size.zero) return;
    // Topmost first: whatever is drawn over everything else is what was tapped.
    final zoom = _controller.value.getMaxScaleOnAxis();
    for (final location in _visible.reversed) {
      // A marker is chrome, not a building, so its box IS the target. This used
      // to sample the landmark art's alpha channel so a tap fell through the
      // gaps in a silhouette; there is no art to sample any more.
      if (_rectFor(location, _canvas, zoom: zoom).contains(local)) {
        widget.onSelect(location);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The canvas is the map, not the viewport. Everything — terrain,
        // markers, fog — lives inside one transformed layer, which is what
        // makes the whole map pan and zoom together.
        final width = constraints.maxWidth;
        final canvas = Size(width, width * widget.world.mapAspect);
        _canvas = canvas;
        // The map is several screens tall, so an untouched camera opens on the
        // top of the world rather than on the player. Frame the player once,
        // after the first real layout, and then leave the camera alone.
        if (!_framed && canvas.height > 0 && constraints.maxHeight.isFinite) {
          _framed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _frameOn(
                widget.state.currentLocationId,
                constraints.biggest,
                atScale: _openingScale,
              );
            }
          });
        }
        final visible = _visible;
        final clearings = [
          for (final location in visible)
            Offset(
              location.sprite.x * canvas.width,
              location.sprite.y * canvas.height,
            ),
        ];

        return ClipRect(
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: .35,
            maxScale: 4.5,
            // Zero margin keeps the camera inside the world. Panning into empty
            // space is what makes a map feel like a texture instead of a place.
            boundaryMargin: EdgeInsets.zero,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTap(details.localPosition),
              child: SizedBox(
                width: canvas.width,
                height: canvas.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Plates are NOT equal slices. They are different heights,
                    // and giving each an equal fifth squashes the terrain while
                    // the sprite and fog coordinates stay true to the map — so
                    // every landmark lands on the wrong ground. Flex is taken
                    // from the measured art.
                    Column(
                      children: [
                        for (final plateId in widget.world.plateAssetIds)
                          Flexible(
                            flex: ((widget.world.aspectFor(plateId) ?? 1) * 1000)
                                .round()
                                .clamp(1, 1 << 30),
                            child: _Plate(
                              url: widget.world.urlFor(plateId),
                            ),
                          ),
                      ],
                    ),
                    for (final location in visible)
                      _Landmark(
                        view: _controller,
                        rect: _rectFor(location, canvas),
                        sealed:
                            location.visibilityFor(widget.state.flags) ==
                            WorldVisibility.sealed,
                        selected: location.id == widget.selectedId,
                        here: location.id == widget.state.currentLocationId,
                        title: location.title,
                        onSelect: () => widget.onSelect(location),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _FogPainter(
                            fog: _fog,
                            clearings: clearings,
                            radius: canvas.width * .22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF1B1714)),
        child: SizedBox.expand(),
      );
    }
    // The opening holds this same provider. A NetworkImage here would
    // paint from a shelf the gate never warmed, and the player would
    // still watch an empty grid after the sigil.
    return SizedBox.expand(
      child: EverloreNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        placeholder: const ColoredBox(color: Color(0xFF1B1714)),
        errorWidget: const ColoredBox(color: Color(0xFF1B1714)),
      ),
    );
  }
}

class _Landmark extends StatelessWidget {
  const _Landmark({
    required this.view,
    required this.rect,
    required this.sealed,
    required this.selected,
    required this.here,
    required this.title,
    required this.onSelect,
  });

  final TransformationController view;
  final Rect rect;
  final bool sealed;
  final bool selected;
  final bool here;
  final String title;
  final VoidCallback onSelect;

  /// A place pinned on a painting that already shows it.
  ///
  /// Drawn from a zero-size box at the location's point and allowed to overflow,
  /// so the pin hangs off the exact spot no matter how the map is scaled, and
  /// inverse-scaled so it stays the same size on screen at every zoom.
  Widget _buildMarker() {
    return Positioned.fromRect(
      rect: Rect.fromCenter(center: rect.center, width: 0, height: 0),
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: ValueListenableBuilder<Matrix4>(
          valueListenable: view,
          builder: (context, m, _) {
            final zoom = m.getMaxScaleOnAxis();
            final screen = MatrixUtils.transformPoint(m, rect.center);
            final scaler = MediaQuery.textScalerOf(context);
            // A landmark under the title used to print its name through
            // the world's own. The letters are withheld while they would
            // sit in that band; the pin stays, and the card still names
            // the place.
            final chromeTop =
                12 +
                (scaler.scale(12) + scaler.scale(20) + 6).clamp(48.0, 88.0);
            final labelClear = screen.dy + 18 >= chromeTop;
            return Transform.scale(
              scale: zoom <= 0 ? 1 : 1 / zoom,
              child: Semantics(
                button: true,
                selected: selected,
                // The pins are hit-tested by coordinate so a tap lands on
                // the painting. Without a node per marker a reader hears
                // an empty landscape.
                label: here ? '$title. You stand here.' : title,
                onTap: onSelect,
                child: IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.18 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: _pin(),
                      ),
                      if (labelClear) ...[
                        const SizedBox(height: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            title,
                            maxLines: 1,
                            // At a raised text scale a visible overflow
                            // painted through the next place's name, so
                            // two landmarks read as one.
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: EverloreTheme.ui(
                              size: 13,
                              height: 1.1,
                              spacing: .3,
                              color: selected
                                  ? const Color(0xFFF6E9CC)
                                  : const Color(0xDDE6D6B4),
                              weight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ).copyWith(
                              shadows: const [
                                Shadow(
                                  color: Color(0xF2000000),
                                  blurRadius: 5,
                                ),
                                Shadow(
                                  color: Color(0xB3000000),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pin() {
    final brass = selected ? const Color(0xFFE8C87A) : const Color(0xFFC8A96A);
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A soft ground glow, so the pin reads against both pale stone and
          // dark forest without a hard plate behind it.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  brass.withValues(alpha: selected ? .45 : .28),
                  const Color(0x00000000),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: here ? brass : const Color(0xE6120E0B),
              shape: BoxShape.circle,
              border: Border.all(color: brass, width: 1.6),
              boxShadow: const [
                BoxShadow(color: Color(0xB3000000), blurRadius: 6),
              ],
            ),
            child: sealed
                ? Icon(
                    Icons.lock_rounded,
                    size: 8,
                    color: here ? const Color(0xFF120E0B) : brass,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildMarker();
}
