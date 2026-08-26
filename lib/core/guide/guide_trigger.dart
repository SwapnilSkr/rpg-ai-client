import 'package:flutter/widgets.dart';

import 'guide_beat.dart';
import 'guide_controller.dart';

/// Starts [flow] the first time this subtree is mounted, and never again.
///
/// The ordinary way a surface opts into the guide: wrap the screen body, and
/// the arc runs on first arrival. Everything about whether it *should* run —
/// prior record, version, opt-out — is decided by the controller, so this stays
/// a declaration rather than a condition at every call site.
class GuideOnEnter extends StatefulWidget {
  final GuideFlow flow;
  final Widget child;

  /// Time for the surface to settle before the first beat looks for its target.
  final Duration delay;

  /// Hold the arc back until the surface has something worth pointing at —
  /// an empty Chronicle teaches nothing.
  final bool enabled;

  const GuideOnEnter({
    super.key,
    required this.flow,
    required this.child,
    this.delay = const Duration(milliseconds: 550),
    this.enabled = true,
  });

  @override
  State<GuideOnEnter> createState() => _GuideOnEnterState();
}

class _GuideOnEnterState extends State<GuideOnEnter> {
  @override
  void initState() {
    super.initState();
    guide.registerTrigger(this, widget.flow, _maybeStart);
    _maybeStart();
  }

  @override
  void dispose() {
    guide.unregisterTrigger(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(GuideOnEnter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Two cases, both real:
    //  - a surface becomes eligible later (its first memory lands);
    //  - a sibling swap reuses this element for a different flow, which happens
    //    when one tab's body replaces another's at the same slot. Without the
    //    id check that second arc would never fire, since initState does not
    //    run again.
    if (oldWidget.flow.id != widget.flow.id) {
      guide.registerTrigger(this, widget.flow, _maybeStart);
    }
    if (oldWidget.flow.id != widget.flow.id ||
        (!oldWidget.enabled && widget.enabled)) {
      _maybeStart();
    }
  }

  void _maybeStart() {
    if (!mounted || !widget.enabled) return;
    guide.maybeStart(widget.flow, delay: widget.delay);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
