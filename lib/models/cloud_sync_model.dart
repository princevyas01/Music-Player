class SyncRecord {
  final String recordId;
  final String domain; // 'favorites', 'playlists', 'history', 'overrides', 'settings', 'smartRules'
  final int version;
  final DateTime updatedAt;
  final String deviceId;
  final Map<String, dynamic> payload;

  const SyncRecord({
    required this.recordId,
    required this.domain,
    required this.version,
    required this.updatedAt,
    required this.deviceId,
    required this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'domain': domain,
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      'deviceId': deviceId,
      'payload': payload,
    };
  }

  factory SyncRecord.fromMap(Map<dynamic, dynamic> map) {
    return SyncRecord(
      recordId: map['recordId'] as String,
      domain: map['domain'] as String,
      version: (map['version'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      deviceId: map['deviceId'] as String? ?? 'local-device',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
    );
  }
}
