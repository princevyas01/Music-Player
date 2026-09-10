enum ScheduledTargetType { playlist, album, smartMix }

class ScheduledPlaybackItem {
  final String id;
  final ScheduledTargetType targetType;
  final String targetId; // playlistId, albumName, or smartMixMode
  final int hour; // 0-23
  final int minute; // 0-59
  final List<int> daysOfWeek; // 1 = Mon ... 7 = Sun. Empty = once
  final bool enabled;
  final String label;

  const ScheduledPlaybackItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.hour,
    required this.minute,
    this.daysOfWeek = const [],
    this.enabled = true,
    required this.label,
  });

  ScheduledPlaybackItem copyWith({
    String? id,
    ScheduledTargetType? targetType,
    String? targetId,
    int? hour,
    int? minute,
    List<int>? daysOfWeek,
    bool? enabled,
    String? label,
  }) {
    return ScheduledPlaybackItem(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetType': targetType.name,
      'targetId': targetId,
      'hour': hour,
      'minute': minute,
      'daysOfWeek': daysOfWeek,
      'enabled': enabled,
      'label': label,
    };
  }

  factory ScheduledPlaybackItem.fromMap(Map<dynamic, dynamic> map) {
    return ScheduledPlaybackItem(
      id: map['id'] as String,
      targetType: ScheduledTargetType.values.firstWhere(
        (e) => e.name == map['targetType'],
        orElse: () => ScheduledTargetType.playlist,
      ),
      targetId: map['targetId'] as String,
      hour: (map['hour'] as num?)?.toInt() ?? 8,
      minute: (map['minute'] as num?)?.toInt() ?? 0,
      daysOfWeek: (map['daysOfWeek'] as List? ?? []).map((e) => (e as num).toInt()).toList(),
      enabled: map['enabled'] as bool? ?? true,
      label: map['label'] as String? ?? 'Scheduled Play',
    );
  }
}
