import 'package:flutter/material.dart';

import '../core/telemetry/telemetry.dart';
import '../shared/widgets/settings_group.dart';

/// The profile switch for sharing usage and crash reports.
///
/// Device-level, not an account preference: it lives in the telemetry store,
/// so there is no server call here. Styled as the mature-themes row beside it.
class SharingSwitchRow extends StatefulWidget {
  const SharingSwitchRow({super.key, Telemetry? telemetry})
    : _telemetry = telemetry;

  final Telemetry? _telemetry;

  @override
  State<SharingSwitchRow> createState() => _SharingSwitchRowState();
}

class _SharingSwitchRowState extends State<SharingSwitchRow> {
  bool _updating = false;

  Telemetry get _t => widget._telemetry ?? Telemetry.instance;

  Future<void> _toggle(bool value) async {
    setState(() => _updating = true);
    await _t.setEnabled(value);
    if (!mounted) return;
    setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchRow(
      icon: Icons.insights_outlined,
      title: 'Share usage and crash reports',
      subtitle:
          'Helps us find and fix problems. Never includes what you write.',
      value: _t.enabled,
      onChanged: _updating ? null : _toggle,
      busy: _updating,
    );
  }
}
