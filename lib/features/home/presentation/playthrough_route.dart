/// Where a save actually plays.
///
/// Chat realms live at `/play/:id`. Walkable map worlds live at
/// `/interactive/:worldKey/lab`. Sending a walk to `/play` is how the player
/// was dropped into a narrator with no map, and sending a chat save to the
/// map is how someone else's story minted map state onto the wrong instance.
String playthroughLocation({
  required String instanceId,
  String? interactiveWorldKey,
}) {
  final key = interactiveWorldKey?.trim() ?? '';
  if (key.isEmpty) return '/play/$instanceId';
  return '/interactive/$key/lab?instanceId=$instanceId';
}

/// The authored map key nested on a template summary, or null for a chat world.
String? interactiveWorldKeyOf(Map<String, dynamic>? template) {
  final value = template?['interactive_world_key'];
  if (value is! String) return null;
  final key = value.trim();
  return key.isEmpty ? null : key;
}
