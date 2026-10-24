import 'package:flutter/material.dart';

import '../core/telemetry/telemetry.dart';
import '../app/theme/nexus_theme.dart';

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
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _t.enabled,
      onChanged: _updating ? null : _toggle,
      activeThumbColor: EverloreTheme.crimson,
      activeTrackColor: EverloreTheme.crimson.withValues(alpha: 0.35),
      title: const Text(
        'Share usage and crash reports',
        style: TextStyle(
          color: EverloreTheme.parchment,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _updating
            ? 'Updating...'
            : 'Helps us find and fix problems. Never includes what you write.',
        style: const TextStyle(color: EverloreTheme.ash, fontSize: 12),
      ),
    );
  }
}
