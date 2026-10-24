import 'dart:convert';

import 'package:everlore/screens/sharing_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('turning the switch off calls setEnabled(false) and reads off', (
    tester,
  ) async {
    late Rig rig;
    await tester.runAsync(() async {
      rig = Rig();
      await rig.start();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SharingSwitchRow(telemetry: rig.telemetry)),
      ),
    );
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.text('Share usage and crash reports'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(rig.telemetry.enabled, isFalse);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    // The one last event went out before the queue was wiped.
    final names = [
      for (final b in rig.transport.bodies)
        for (final e in jsonDecode(b)['events'] as List) e['name'],
    ];
    expect(names, contains('analytics_opted_out'));
  });
}
