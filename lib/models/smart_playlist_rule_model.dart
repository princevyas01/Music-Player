enum SmartRuleField {
  artist,
  album,
  genre,
  year,
  duration,
  dateAdded,
  lastPlayed,
  playCount,
  skipCount,
  completionCount,
  neverPlayed,
  recentlyPlayed,
  recentlyAdded,
  favorites,
  playlistMembership,
}

enum SmartRuleOperator {
  equals,
  contains,
  greaterThan,
  lessThan,
  isTrue,
  isFalse,
}

class SmartRule {
  final SmartRuleField field;
  final SmartRuleOperator operator;
  final dynamic value;

  const SmartRule({
    required this.field,
    required this.operator,
    this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'field': field.name,
      'operator': operator.name,
      'value': value,
    };
  }

  factory SmartRule.fromMap(Map<dynamic, dynamic> map) {
    return SmartRule(
      field: SmartRuleField.values.firstWhere(
        (e) => e.name == map['field'],
        orElse: () => SmartRuleField.artist,
      ),
      operator: SmartRuleOperator.values.firstWhere(
        (e) => e.name == map['operator'],
        orElse: () => SmartRuleOperator.equals,
      ),
      value: map['value'],
    );
  }
}

enum SmartSortOption {
  recommended,
  recentlyPlayed,
  leastRecentlyPlayed,
  mostPlayed,
  leastPlayed,
  title,
  artist,
  album,
  dateAdded,
  duration,
}

class SmartPlaylistDefinition {
  final String id;
  final String name;
  final List<SmartRule> rules;
  final bool matchAll; // true = AND, false = OR
  final SmartSortOption sortOption;
  final int? limit; // null = no limit, 10, 25, 50, 100

  const SmartPlaylistDefinition({
    required this.id,
    required this.name,
    required this.rules,
    this.matchAll = true,
    this.sortOption = SmartSortOption.recommended,
    this.limit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rules': rules.map((r) => r.toMap()).toList(),
      'matchAll': matchAll,
      'sortOption': sortOption.name,
      'limit': limit,
    };
  }

  factory SmartPlaylistDefinition.fromMap(Map<dynamic, dynamic> map) {
    return SmartPlaylistDefinition(
      id: map['id'] as String,
      name: map['name'] as String,
      rules: (map['rules'] as List? ?? [])
          .map((r) => SmartRule.fromMap(r as Map))
          .toList(),
      matchAll: map['matchAll'] as bool? ?? true,
      sortOption: SmartSortOption.values.firstWhere(
        (e) => e.name == map['sortOption'],
        orElse: () => SmartSortOption.recommended,
      ),
      limit: (map['limit'] as num?)?.toInt(),
    );
  }
}
