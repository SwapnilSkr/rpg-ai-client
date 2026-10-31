import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'rig_art.dart';
import 'rig_frame_stats.dart';
import 'rig_painter.dart';
import 'rig_quality.dart';
import 'rig_sim.dart';
import 'rig_tuning.dart';

const Color _stage = Color(0xFF0F0C0A);

/// Where the orchestrator pushes the art, when path_provider has no answer.
const String _fallbackDir = '/sdcard/Android/data/com.everloreapp/files/rig';

/// Finds the art folder, loads it, and shows the test screen or a plain message.
class RigLoadScreen extends StatefulWidget {
  const RigLoadScreen({super.key});

  @override
  State<RigLoadScreen> createState() => _RigLoadScreenState();
}

class _RigLoadScreenState extends State<RigLoadScreen> {
  late final Future<RigArtSet> _art = _load();
  String _path = _fallbackDir;

  Future<RigArtSet> _load() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) _path = '${ext.path}/rig';
    } catch (_) {
      // Keep the fallback path in the message.
    }
    return loadRigArt(Directory(_path), displayHeightPx: _displayHeightPx());
  }

  /// The rig fills the screen's height, so this is the scale the art is drawn
  /// at: the textures can be decoded for it instead of at full canvas size.
  static double _displayHeightPx() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 0 : views.first.physicalSize.height;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RigArtSet>(
      future: _art,
      builder: (context, snap) {
        if (snap.hasData) return RigScreen(art: snap.data!);
        return Scaffold(
          backgroundColor: _stage,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snap.hasError
                  ? Text(
                      'The character art was not found.\n\n'
                      'Put rig.json and the layer PNGs in:\n$_path\n\n'
                      '(${snap.error})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }
}

class RigScreen extends StatefulWidget {
  const RigScreen({super.key, required this.art});

  final RigArtSet art;

  @override
  State<RigScreen> createState() => _RigScreenState();
}

class _RigScreenState extends State<RigScreen>
    with SingleTickerProviderStateMixin {
  late final RigSim _sim = RigSim(
    deformer: widget.art.deformer,
    quality: widget.art.quality,
  );
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final FrameStats _ticks = FrameStats();
  final FrameStats _raster = FrameStats();
  final ValueNotifier<String> _fps = ValueNotifier<String>('');
  final ValueNotifier<String?> _benchText = ValueNotifier<String?>(null);
  final Stopwatch _clock = Stopwatch()..start();
  late final QualityGovernor _quality =
      QualityGovernor(start: widget.art.quality);

  int _lastReadout = 0;
  int? _firstVsync;
  Size _screenPx = Size.zero;
  bool _wasRecording = false;
  bool _wasBenchmarking = false;
  final List<double> _benchBuild = [];
  final List<double> _benchRaster = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _sim.uiRevision.addListener(_onUi);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenPx = View.of(context).physicalSize;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final now = _clock.elapsedMicroseconds;
    if (dt > 0) _ticks.add(now, dt * 1000);
    _sim.update(dt);
    if (now - _lastReadout > 250000) {
      _lastReadout = now;
      final t = _ticks.snapshot(now);
      final r = _raster.snapshot(now);
      _fps.value = '${t.count} fps  avg ${t.avgMs.toStringAsFixed(1)}  '
          'worst ${t.worstMs.toStringAsFixed(1)} ms'
          '${r.count > 0 ? '  raster worst ${r.worstMs.toStringAsFixed(1)}' : ''}'
          '  · ${_quality.label}';
    }
  }

  // Frame timings arrive in batches; keep the build + raster span of each, feed
  // the tier's judge while it is still deciding, and keep every frame while the
  // benchmark runs.
  void _onTimings(List<ui.FrameTiming> timings) {
    final now = _clock.elapsedMicroseconds;
    for (final t in timings) {
      final raster = t.rasterDuration.inMicroseconds / 1000;
      _raster.add(now, raster);
      final vsync = t.timestampInMicroseconds(ui.FramePhase.vsyncStart);
      _firstVsync ??= vsync;
      final sinceStart = (vsync - _firstVsync!) / 1e6;
      if (_quality.addRaster(raster, sinceStart)) {
        _applyQuality(_quality.quality);
      }
      if (_sim.benchmarking) {
        _benchBuild.add(t.buildDuration.inMicroseconds / 1000);
        _benchRaster.add(raster);
      }
    }
  }

  /// Switches the tier everywhere: the meshes are rebuilt at the new density and
  /// the hair springs follow the new column count.
  void _applyQuality(RigQuality q) {
    widget.art.setQuality(q);
    _sim.setQuality(q);
    setState(() {});
  }

  void _toggleQuality() {
    _quality.choose(
      _quality.quality == RigQuality.high ? RigQuality.low : RigQuality.high,
    );
    _applyQuality(_quality.quality);
  }

  void _startBench() {
    if (_sim.benchmarking || _sim.recording) return;
    _benchBuild.clear();
    _benchRaster.clear();
    _benchText.value = null;
    _wasBenchmarking = true;
    _sim.startBenchmark();
  }

  /// Turns the run's frame times into the numbers the orchestrator reads, and
  /// prints ONE line so `adb logcat | grep RIGBENCH` finds it.
  void _finishBench() {
    final build = FramePercentiles.of(_benchBuild);
    final raster = FramePercentiles.of(_benchRaster);
    final tier = _quality.quality.name;
    final screen = '${_screenPx.width.round()}x${_screenPx.height.round()}';
    debugPrint('RIGBENCH ${jsonEncode({
      'quality': tier,
      'screen': screen,
      'seconds': RigTuning.benchSeconds,
      'frames': raster.count,
      'build': {
        'p50': _round(build.p50),
        'p90': _round(build.p90),
        'p99': _round(build.p99),
      },
      'raster': {
        'p50': _round(raster.p50),
        'p90': _round(raster.p90),
        'p99': _round(raster.p99),
      },
      'over16ms': {'build': build.overBudget, 'raster': raster.overBudget},
      'over33ms': {'build': build.overStutter, 'raster': raster.overStutter},
    })}');
    _benchText.value = [
      'BENCH · $tier · $screen · ${raster.count} frames',
      'build   p50 ${_ms(build.p50)}  p90 ${_ms(build.p90)}  p99 ${_ms(build.p99)} ms',
      'raster  p50 ${_ms(raster.p50)}  p90 ${_ms(raster.p90)}  p99 ${_ms(raster.p99)} ms',
      'over 16.7 ms: build ${build.overBudget}  raster ${raster.overBudget}',
      'over 33 ms:   build ${build.overStutter}  raster ${raster.overStutter}',
    ].join('\n');
  }

  static String _ms(double v) => v.toStringAsFixed(1);

  /// One decimal place, still a JSON number rather than a string.
  static double _round(double v) => (v * 10).roundToDouble() / 10;

  // Record mode hides the system bars so the clip is only the character; the
  // benchmark's end is what turns its numbers into a panel.
  void _onUi() {
    final rec = _sim.recording;
    if (rec != _wasRecording) {
      _wasRecording = rec;
      SystemChrome.setEnabledSystemUIMode(
        rec ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
    if (_wasBenchmarking && !_sim.benchmarking) {
      _wasBenchmarking = false;
      _finishBench();
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    _sim.uiRevision.removeListener(_onUi);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _sim.dispose();
    _fps.dispose();
    _benchText.dispose();
    widget.art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _stage,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: _sim.startRecord,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: RigPainter(art: widget.art, sim: _sim),
                size: Size.infinite,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: _sim.uiRevision,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BenchPanel(text: _benchText),
                    _Subtitle(text: _sim.subtitle),
                    if (!_sim.recording) _controls(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1512),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SegmentedButton<RigMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: RigMode.paperDoll, label: Text('A  paper doll')),
                  ButtonSegment(value: RigMode.mesh, label: Text('B  mesh')),
                ],
                selected: {_sim.mode},
                onSelectionChanged: (s) => _sim.setMode(s.first),
              ),
              const Spacer(),
              const Text('Outfit'),
              Switch(value: _sim.outfit, onChanged: _sim.setOutfit),
            ],
          ),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(onPressed: _sim.talk, child: const Text('Talk')),
              TextButton(onPressed: _sim.lookAway, child: const Text('Look away')),
              TextButton(
                onPressed: _sim.nextExpression,
                child: Text('Next: ${_sim.expression.target.name}'),
              ),
              TextButton(
                onPressed: _sim.benchmarking || _sim.recording ? null : _startBench,
                child: Text(_sim.benchmarking ? 'Bench…' : 'Bench'),
              ),
              TextButton(
                onPressed: _toggleQuality,
                child: Text('Quality: ${_quality.quality.name}'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _fps,
                  builder: (_, v, _) => Text(
                    v,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ),
              ),
              const Text(
                'long-press the picture to record',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The benchmark's numbers, in the panel above the subtitle. Tap to dismiss.
class _BenchPanel extends StatelessWidget {
  const _BenchPanel({required this.text});

  final ValueNotifier<String?> text;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: text,
      builder: (_, body, _) {
        if (body == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => text.value = null,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xCC1A1512),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              body,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
                color: Colors.white70,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text});

  final ValueNotifier<String?> text;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: text,
      builder: (_, line, _) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          line ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            height: 1.3,
            shadows: [Shadow(blurRadius: 6), Shadow(blurRadius: 12)],
          ),
        ),
      ),
    );
  }
}
