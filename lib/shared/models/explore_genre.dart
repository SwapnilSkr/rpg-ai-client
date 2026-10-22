class GenreStyleCount {
  final int worlds;
  final int characters;

  const GenreStyleCount({
    this.worlds = 0,
    this.characters = 0,
  });

  int get total => worlds + characters;

  int countForKind(String? kind) {
    if (kind == 'world') return worlds;
    if (kind == 'character') return characters;
    return total;
  }

  factory GenreStyleCount.fromJson(dynamic val) {
    if (val is num) {
      final count = val.toInt();
      // Bare number (old contract): treat as available for both kinds.
      return GenreStyleCount(worlds: count, characters: count);
    }
    if (val is Map) {
      final w = (val['worlds'] as num?)?.toInt() ?? 0;
      final c = (val['characters'] as num?)?.toInt() ?? 0;
      return GenreStyleCount(worlds: w, characters: c);
    }
    return const GenreStyleCount();
  }

  Map<String, dynamic> toJson() => {
    'worlds': worlds,
    'characters': characters,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenreStyleCount &&
          runtimeType == other.runtimeType &&
          worlds == other.worlds &&
          characters == other.characters;

  @override
  int get hashCode => Object.hash(worlds, characters);
}

class ExploreGenre {
  final String key;
  final String label;
  final int worlds;
  final int characters;
  final Map<String, GenreStyleCount> styles;

  const ExploreGenre({
    required this.key,
    required this.label,
    this.worlds = 0,
    this.characters = 0,
    this.styles = const {},
  });

  int get total => worlds + characters;
  bool get hasContent => total > 0;

  Set<String> availableStylesForKind(String? kind) {
    final result = <String>{};
    for (final entry in styles.entries) {
      if (entry.value.countForKind(kind) > 0) {
        result.add(entry.key);
      }
    }
    return result;
  }

  factory ExploreGenre.fromJson(Map<String, dynamic> json) {
    final stylesMap = <String, GenreStyleCount>{};
    final rawStyles = json['styles'];
    if (rawStyles is Map) {
      for (final entry in rawStyles.entries) {
        stylesMap[entry.key.toString()] = GenreStyleCount.fromJson(entry.value);
      }
    }

    return ExploreGenre(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      worlds: (json['worlds'] as num?)?.toInt() ?? 0,
      characters: (json['characters'] as num?)?.toInt() ?? 0,
      styles: stylesMap,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'worlds': worlds,
    'characters': characters,
    'styles': styles.map((k, v) => MapEntry(k, v.toJson())),
  };
}
