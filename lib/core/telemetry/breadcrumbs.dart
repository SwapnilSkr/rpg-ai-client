/// The last few things the player did, copied into every error report so a
/// crash arrives with the steps that led to it.
///
/// Names are screen names, event names from the closed vocabulary, or
/// `http_<status>` / lifecycle words. Never text the player typed.
library;

class Breadcrumb {
  const Breadcrumb({required this.at, required this.kind, required this.name});

  final DateTime at;

  /// `screen` | `action` | `http` | `lifecycle`
  final String kind;
  final String name;

  Map<String, Object> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'kind': kind,
    'name': name,
  };
}

class BreadcrumbRing {
  BreadcrumbRing({this.capacity = 20});

  final int capacity;
  final List<Breadcrumb> _items = [];

  void add(Breadcrumb crumb) {
    _items.add(crumb);
    if (_items.length > capacity) _items.removeAt(0);
  }

  List<Breadcrumb> snapshot() => List.unmodifiable(_items);

  void clear() => _items.clear();
}
