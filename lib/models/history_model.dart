class PlaybackHistory {
  final String trackId;
  final int playCount;
  final int completedPlayCount;
  final DateTime lastPlayedAt;
  final int totalListenDurationMs;
  final int lastPositionMs;
  final int skipCount;
  final Map<String, int> dailyListenDurationMs;

  PlaybackHistory({
    required this.trackId,
    this.playCount = 0,
    this.completedPlayCount = 0,
    required this.lastPlayedAt,
    this.totalListenDurationMs = 0,
    this.lastPositionMs = 0,
    this.skipCount = 0,
    this.dailyListenDurationMs = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'playCount': playCount,
      'completedPlayCount': completedPlayCount,
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'totalListenDurationMs': totalListenDurationMs,
      'lastPositionMs': lastPositionMs,
      'skipCount': skipCount,
      'dailyListenDurationMs': dailyListenDurationMs,
    };
  }

  factory PlaybackHistory.fromMap(Map<dynamic, dynamic> map) {
    return PlaybackHistory(
      trackId: map['trackId'] as String,
      playCount: (map['playCount'] as num?)?.toInt() ?? 0,
      completedPlayCount: (map['completedPlayCount'] as num?)?.toInt() ?? 0,
      lastPlayedAt: map['lastPlayedAt'] != null
          ? DateTime.tryParse(map['lastPlayedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalListenDurationMs: (map['totalListenDurationMs'] as num?)?.toInt() ?? 0,
      lastPositionMs: (map['lastPositionMs'] as num?)?.toInt() ?? 0,
      skipCount: (map['skipCount'] as num?)?.toInt() ?? 0,
      dailyListenDurationMs: (map['dailyListenDurationMs'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ??
          const {},
    );
  }

  PlaybackHistory copyWith({
    String? trackId,
    int? playCount,
    int? completedPlayCount,
    DateTime? lastPlayedAt,
    int? totalListenDurationMs,
    int? lastPositionMs,
    int? skipCount,
    Map<String, int>? dailyListenDurationMs,
  }) {
    return PlaybackHistory(
      trackId: trackId ?? this.trackId,
      playCount: playCount ?? this.playCount,
      completedPlayCount: completedPlayCount ?? this.completedPlayCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      totalListenDurationMs: totalListenDurationMs ?? this.totalListenDurationMs,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      skipCount: skipCount ?? this.skipCount,
      dailyListenDurationMs: dailyListenDurationMs ?? this.dailyListenDurationMs,
    );
  }
}

