import 'package:flutter/widgets.dart';

/// True when the platform asks apps to minimize animation (accessibility).
/// Gamification flourishes (staggered chips, floating deltas, seal bursts)
/// must collapse to their static end-states when this is set.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
