class WaveformData {
  final String trackId;
  final List<double> amplitudes;
  final int durationMs;

  const WaveformData({
    required this.trackId,
    required this.amplitudes,
    required this.durationMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'amplitudes': amplitudes,
      'durationMs': durationMs,
    };
  }

  factory WaveformData.fromMap(Map<dynamic, dynamic> map) {
    return WaveformData(
      trackId: map['trackId'] as String,
      amplitudes: (map['amplitudes'] as List? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
    );
  }
}
