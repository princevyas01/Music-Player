import 'track_model.dart';

class QueueItem {
  final String queueId;
  final Track track;
  final DateTime addedAt;
  final bool isAutoSuggested;

  const QueueItem({
    required this.queueId,
    required this.track,
    required this.addedAt,
    this.isAutoSuggested = false,
  });

  QueueItem copyWith({
    String? queueId,
    Track? track,
    DateTime? addedAt,
    bool? isAutoSuggested,
  }) {
    return QueueItem(
      queueId: queueId ?? this.queueId,
      track: track ?? this.track,
      addedAt: addedAt ?? this.addedAt,
      isAutoSuggested: isAutoSuggested ?? this.isAutoSuggested,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'queueId': queueId,
      'track': track.toMap(),
      'addedAt': addedAt.toIso8601String(),
      'isAutoSuggested': isAutoSuggested,
    };
  }

  factory QueueItem.fromMap(Map<dynamic, dynamic> map) {
    return QueueItem(
      queueId: map['queueId'] as String,
      track: Track.fromMap(map['track'] as Map),
      addedAt: DateTime.parse(map['addedAt'] as String),
      isAutoSuggested: map['isAutoSuggested'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItem &&
          runtimeType == other.runtimeType &&
          queueId == other.queueId;

  @override
  int get hashCode => queueId.hashCode;
}
