class FeatureFlags {
  final bool enableAdvancedSearch;
  final bool enableArtworkPipeline;
  final bool enableWaveform;
  final bool enableLyrics;
  final bool enableEqualizer;
  final bool enableVolumeNormalization;
  final bool enableRecommendationsV2;
  final bool enableAdaptiveQueue;
  final bool enableSmartPlaylistBuilder;
  final bool enableSessions;
  final bool enableAdvancedAnalytics;
  final bool enableWidgets;
  final bool enableScheduledPlayback;
  final bool enableCloudSync;
  final bool enableExternalPlayback;

  const FeatureFlags({
    // Every extension defaults to off so installing an update cannot change
    // established playback or platform behaviour without the user's consent.
    this.enableAdvancedSearch = false,
    this.enableArtworkPipeline = false,
    this.enableWaveform = false,
    this.enableLyrics = false,
    this.enableEqualizer = false,
    this.enableVolumeNormalization = false,
    this.enableRecommendationsV2 = false,
    this.enableAdaptiveQueue = false,
    this.enableSmartPlaylistBuilder = false,
    this.enableSessions = false,
    this.enableAdvancedAnalytics = false,
    this.enableWidgets = false,
    this.enableScheduledPlayback = false,
    this.enableCloudSync = false,
    this.enableExternalPlayback = false,
  });

  FeatureFlags copyWith({
    bool? enableAdvancedSearch,
    bool? enableArtworkPipeline,
    bool? enableWaveform,
    bool? enableLyrics,
    bool? enableEqualizer,
    bool? enableVolumeNormalization,
    bool? enableRecommendationsV2,
    bool? enableAdaptiveQueue,
    bool? enableSmartPlaylistBuilder,
    bool? enableSessions,
    bool? enableAdvancedAnalytics,
    bool? enableWidgets,
    bool? enableScheduledPlayback,
    bool? enableCloudSync,
    bool? enableExternalPlayback,
  }) {
    return FeatureFlags(
      enableAdvancedSearch: enableAdvancedSearch ?? this.enableAdvancedSearch,
      enableArtworkPipeline: enableArtworkPipeline ?? this.enableArtworkPipeline,
      enableWaveform: enableWaveform ?? this.enableWaveform,
      enableLyrics: enableLyrics ?? this.enableLyrics,
      enableEqualizer: enableEqualizer ?? this.enableEqualizer,
      enableVolumeNormalization: enableVolumeNormalization ?? this.enableVolumeNormalization,
      enableRecommendationsV2: enableRecommendationsV2 ?? this.enableRecommendationsV2,
      enableAdaptiveQueue: enableAdaptiveQueue ?? this.enableAdaptiveQueue,
      enableSmartPlaylistBuilder: enableSmartPlaylistBuilder ?? this.enableSmartPlaylistBuilder,
      enableSessions: enableSessions ?? this.enableSessions,
      enableAdvancedAnalytics: enableAdvancedAnalytics ?? this.enableAdvancedAnalytics,
      enableWidgets: enableWidgets ?? this.enableWidgets,
      enableScheduledPlayback: enableScheduledPlayback ?? this.enableScheduledPlayback,
      enableCloudSync: enableCloudSync ?? this.enableCloudSync,
      enableExternalPlayback: enableExternalPlayback ?? this.enableExternalPlayback,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableAdvancedSearch': enableAdvancedSearch,
      'enableArtworkPipeline': enableArtworkPipeline,
      'enableWaveform': enableWaveform,
      'enableLyrics': enableLyrics,
      'enableEqualizer': enableEqualizer,
      'enableVolumeNormalization': enableVolumeNormalization,
      'enableRecommendationsV2': enableRecommendationsV2,
      'enableAdaptiveQueue': enableAdaptiveQueue,
      'enableSmartPlaylistBuilder': enableSmartPlaylistBuilder,
      'enableSessions': enableSessions,
      'enableAdvancedAnalytics': enableAdvancedAnalytics,
      'enableWidgets': enableWidgets,
      'enableScheduledPlayback': enableScheduledPlayback,
      'enableCloudSync': enableCloudSync,
      'enableExternalPlayback': enableExternalPlayback,
    };
  }

  factory FeatureFlags.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const FeatureFlags();
    return FeatureFlags(
      enableAdvancedSearch: map['enableAdvancedSearch'] as bool? ?? false,
      enableArtworkPipeline: map['enableArtworkPipeline'] as bool? ?? false,
      enableWaveform: map['enableWaveform'] as bool? ?? false,
      enableLyrics: map['enableLyrics'] as bool? ?? false,
      enableEqualizer: map['enableEqualizer'] as bool? ?? false,
      enableVolumeNormalization: map['enableVolumeNormalization'] as bool? ?? false,
      enableRecommendationsV2: map['enableRecommendationsV2'] as bool? ?? false,
      enableAdaptiveQueue: map['enableAdaptiveQueue'] as bool? ?? false,
      enableSmartPlaylistBuilder: map['enableSmartPlaylistBuilder'] as bool? ?? false,
      enableSessions: map['enableSessions'] as bool? ?? false,
      enableAdvancedAnalytics: map['enableAdvancedAnalytics'] as bool? ?? false,
      enableWidgets: map['enableWidgets'] as bool? ?? false,
      enableScheduledPlayback: map['enableScheduledPlayback'] as bool? ?? false,
      enableCloudSync: map['enableCloudSync'] as bool? ?? false,
      enableExternalPlayback: map['enableExternalPlayback'] as bool? ?? false,
    );
  }
}
