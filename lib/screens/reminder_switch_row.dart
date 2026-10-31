import 'package:flutter/material.dart';

import '../core/reminders/reminder_service.dart';
import '../shared/widgets/everlore_notice.dart';
import '../shared/widgets/settings_group.dart';

/// The Settings switch for story reminders.
///
/// The service owns the truth; this only reflects [ReminderService.enabled].
/// Turning on without the system permission sends the player to the system
/// settings, so the switch stays off and the way back is the app resuming.
class ReminderSwitchRow extends StatefulWidget {
  const ReminderSwitchRow({super.key, ReminderService? service})
    : _service = service;

  final ReminderService? _service;

  @override
  State<ReminderSwitchRow> createState() => _ReminderSwitchRowState();
}

class _ReminderSwitchRowState extends State<ReminderSwitchRow>
    with WidgetsBindingObserver {
  bool _updating = false;

  /// What is really so: switched on AND the system lets it fire. The stored
  /// flag alone stays true after the player revokes the permission.
  bool? _on;

  ReminderService get _s => widget._service ?? ReminderService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    final active = await _s.isActive();
    if (!mounted) return;
    setState(() => _on = active);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system settings the permission may have changed. Re-read
  // it; never flip the switch on the player's behalf.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  Future<void> _toggle(bool value) async {
    setState(() => _updating = true);
    ReminderToggleResult? result;
    try {
      result = await _s.setEnabled(value);
    } catch (_) {
      // The switch simply reflects whatever the service ended up holding.
    }
    if (!mounted) return;
    bool active;
    try {
      active = await _s.isActive();
    } catch (_) {
      active = _s.enabled;
    }
    if (!mounted) return;
    setState(() {
      _updating = false;
      _on = active;
    });
    if (result == ReminderToggleResult.needsSystemSettings) {
      showEverloreNotice(
        context,
        'Allow notifications for Everlore, then turn this on.',
        tone: NoticeTone.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchRow(
      icon: Icons.notifications_none_rounded,
      title: 'Story reminders',
      subtitle: 'A gentle nudge when a story is waiting.',
      value: _on ?? _s.enabled,
      onChanged: _updating ? null : _toggle,
      busy: _updating,
    );
  }
}
