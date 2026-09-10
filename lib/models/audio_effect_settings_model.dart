class AudioEffectSettings {
  final bool enabled;
  final String selectedPreset; // Flat, Rock, Pop, Classical, Jazz, Bass Boost, Vocal, Custom
  final List<double> bandGains; // 10 bands: 31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz (-12.0 to +12.0 dB)
  final double bassBoost; // 0.0 to 1.0
  final double midBoost; // 0.0 to 1.0
  final double trebleBoost; // 0.0 to 1.0
  final double loudnessGain; // 0.0 to 1.0
  final bool volumeNormalization;

  static const List<int> standardFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
  ];

  static const Map<String, List<double>> presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.5, 3.5, 2.0, 0.0, -1.0, 0.5, 2.0, 3.5, 4.0, 4.5],
    'Pop': [-1.5, -0.5, 1.0, 2.5, 3.5, 3.0, 1.5, 0.0, 1.0, 2.0],
    'Classical': [3.5, 3.0, 2.5, 1.5, -0.5, -0.5, 0.0, 1.5, 2.5, 3.0],
    'Jazz': [3.0, 2.0, 1.0, 1.5, -1.0, -1.0, 0.5, 1.5, 2.5, 3.5],
    'Bass Boost': [6.0, 5.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Vocal': [-2.0, -1.5, -0.5, 1.5, 3.5, 3.5, 2.5, 1.0, 0.0, -1.0],
  };

  const AudioEffectSettings({
    this.enabled = false,
    this.selectedPreset = 'Flat',
    this.bandGains = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.bassBoost = 0.0,
    this.midBoost = 0.0,
    this.trebleBoost = 0.0,
    this.loudnessGain = 0.0,
    this.volumeNormalization = false,
  });

  AudioEffectSettings copyWith({
    bool? enabled,
    String? selectedPreset,
    List<double>? bandGains,
    double? bassBoost,
    double? midBoost,
    double? trebleBoost,
    double? loudnessGain,
    bool? volumeNormalization,
  }) {
    return AudioEffectSettings(
      enabled: enabled ?? this.enabled,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      bandGains: bandGains ?? this.bandGains,
      bassBoost: bassBoost ?? this.bassBoost,
      midBoost: midBoost ?? this.midBoost,
      trebleBoost: trebleBoost ?? this.trebleBoost,
      loudnessGain: loudnessGain ?? this.loudnessGain,
      volumeNormalization: volumeNormalization ?? this.volumeNormalization,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'selectedPreset': selectedPreset,
      'bandGains': bandGains,
      'bassBoost': bassBoost,
      'midBoost': midBoost,
      'trebleBoost': trebleBoost,
      'loudnessGain': loudnessGain,
      'volumeNormalization': volumeNormalization,
    };
  }

  factory AudioEffectSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const AudioEffectSettings();
    final rawGains = (map['bandGains'] as List? ?? []);
    List<double> gains;
    if (rawGains.length == 10) {
      gains = rawGains.map((e) => (e as num).toDouble()).toList();
    } else {
      gains = List.filled(10, 0.0);
    }

    return AudioEffectSettings(
      enabled: map['enabled'] as bool? ?? false,
      selectedPreset: map['selectedPreset'] as String? ?? 'Flat',
      bandGains: gains,
      bassBoost: (map['bassBoost'] as num?)?.toDouble() ?? 0.0,
      midBoost: (map['midBoost'] as num?)?.toDouble() ?? 0.0,
      trebleBoost: (map['trebleBoost'] as num?)?.toDouble() ?? 0.0,
      loudnessGain: (map['loudnessGain'] as num?)?.toDouble() ?? 0.0,
      volumeNormalization: map['volumeNormalization'] as bool? ?? false,
    );
  }
}
