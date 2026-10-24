/// The screen a player is on, as the route declares it.
library;

import 'package:go_router/go_router.dart';

/// The matched `GoRoute.name` of the deepest visible route, `unnamed` for a
/// route without a name, or null before the router has matched anything.
///
/// Never the path: `/play/66f…` would make every story its own "screen" and
/// put an id into the data. A pushed route sits on top of the shell branch, so
/// this follows the same trail `main.dart`'s location lookup does: an
/// imperative match carries its own last route, a shell match is descended.
String? routeNameOf(RouteMatchList list) {
  if (list.matches.isEmpty) return null;
  RouteMatchBase match = list.matches.last;
  while (match is ShellRouteMatch) {
    match = match.matches.last;
  }
  if (match is RouteMatch) {
    final name = match.route.name;
    if (name != null && name.isNotEmpty) return name;
  }
  return 'unnamed';
}
