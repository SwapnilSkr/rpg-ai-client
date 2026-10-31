import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'rig_art.dart';
import 'rig_frame_stats.dart';
import 'rig_painter.dart';
import 'rig_sim.dart';

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
    return loadRigArt(Directory(_path));
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
  late final RigSim _sim = RigSim(deformer: widget.art.deformer);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final FrameStats _ticks = FrameStats();
  final FrameStats _raster = FrameStats();
  final ValueNotifier<String> _fps = ValueNotifier<String>('');
  final Stopwatch _clock = Stopwatch()..start();
  int _lastReadout = 0;
  bool _wasRecording = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _sim.uiRevision.addListener(_syncChrome);
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
          '${r.count > 0 ? '  raster worst ${r.worstMs.toStringAsFixed(1)}' : ''}';
    }
  }

  // Frame timings arrive in batches; keep the build + raster span of each.
  void _onTimings(List<ui.FrameTiming> timings) {
    final now = _clock.elapsedMicroseconds;
    for (final t in timings) {
      _raster.add(now, t.rasterDuration.inMicroseconds / 1000);
    }
  }

  // Record mode hides the system bars so the clip is only the character.
  void _syncChrome() {
    final rec = _sim.recording;
    if (rec == _wasRecording) return;
    _wasRecording = rec;
    SystemChrome.setEnabledSystemUIMode(
      rec ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    _sim.uiRevision.removeListener(_syncChrome);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _sim.dispose();
    _fps.dispose();
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
