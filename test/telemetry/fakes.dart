import 'package:everlore/core/telemetry/environment.dart';
import 'package:everlore/core/telemetry/sender.dart';
import 'package:everlore/core/telemetry/telemetry.dart';

import 'memory_store.dart';

class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 10, 24, 10);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

/// Records every request; answers with the next scripted status.
class FakeTransport implements TelemetryTransport {
  final List<String> bodies = [];
  final List<String?> tokens = [];
  final List<TransportResult> script = [];
  TransportResult fallback = const TransportResult(status: 202);

  @override
  Future<TransportResult> post(String body, {String? token}) async {
    bodies.add(body);
    tokens.add(token);
    return script.isEmpty ? fallback : script.removeAt(0);
  }
}

class Rig {
  Rig({this.token}) {
    telemetry = Telemetry(
      store: store,
      transport: transport,
      now: clock.call,
      tokenProvider: () async => token,
      environment: () async => const TelemetryEnvironment(
        appVersion: '1.0.11',
        appBuild: 14,
        device: {
          'os': 'android',
          'os_version': '35',
          'model': 'Pixel',
          'form': 'phone',
          'locale': 'en-IN',
        },
      ),
      newId: _id,
      journalPath: () async => null,
      observeLifecycle: false,
      startTimers: false,
      installHandlers: false,
    );
  }

  final store = MemoryTelemetryStore();
  final transport = FakeTransport();
  final clock = FakeClock();
  String? token;
  late final Telemetry telemetry;
  int _n = 0;

  /// Distinct, valid-shaped UUIDs.
  String _id() {
    final hex = (++_n).toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$hex';
  }

  Future<void> start() async {
    await telemetry.init();
    await telemetry.settle();
    // init starts a send without waiting; this waits for it.
    await telemetry.flush();
  }
}
