class ListeningSession {
  final String sessionId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMs;
  final int tracksStarted;
  final int tracksCompleted;
  final int tracksSkipped;
  final List<String> trackIds;

  const ListeningSession({
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    this.tracksStarted = 0,
    this.tracksCompleted = 0,
    this.tracksSkipped = 0,
    this.trackIds = const [],
  });

  ListeningSession copyWith({
    String? sessionId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationMs,
    int? tracksStarted,
    int? tracksCompleted,
    int? tracksSkipped,
    List<String>? trackIds,
  }) {
    return ListeningSession(
      sessionId: sessionId ?? this.sessionId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMs: durationMs ?? this.durationMs,
      tracksStarted: tracksStarted ?? this.tracksStarted,
      tracksCompleted: tracksCompleted ?? this.tracksCompleted,
      tracksSkipped: tracksSkipped ?? this.tracksSkipped,
      trackIds: trackIds ?? this.trackIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationMs': durationMs,
      'tracksStarted': tracksStarted,
      'tracksCompleted': tracksCompleted,
      'tracksSkipped': tracksSkipped,
      'trackIds': trackIds,
    };
  }

  factory ListeningSession.fromMap(Map<dynamic, dynamic> map) {
    return ListeningSession(
      sessionId: map['sessionId'] as String,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: DateTime.parse(map['endedAt'] as String),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      tracksStarted: (map['tracksStarted'] as num?)?.toInt() ?? 0,
      tracksCompleted: (map['tracksCompleted'] as num?)?.toInt() ?? 0,
      tracksSkipped: (map['tracksSkipped'] as num?)?.toInt() ?? 0,
      trackIds: List<String>.from(map['trackIds'] ?? []),
    );
  }
}
