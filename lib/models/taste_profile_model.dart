class TasteProfile {
  final String primaryArchetype; // e.g. 'Explorer', 'Album Listener', 'Artist Loyalist', 'Catalog Explorer'
  final String? secondaryArchetype;
  final double explorerScore; // 0.0 to 1.0
  final double albumListenerScore; // 0.0 to 1.0
  final double artistLoyalistScore; // 0.0 to 1.0
  final double catalogExplorerScore; // 0.0 to 1.0
  final double discoveryRatio; // 0.0 to 1.0
  final double completionTendency; // 0.0 to 1.0
  final double repeatTendency; // 0.0 to 1.0
  final String topGenre;
  final String topArtist;
  final String topAlbum;
  final int peakListeningHour; // 0-23
  final int averageSessionMinutes;
  final DateTime computedAt;

  const TasteProfile({
    required this.primaryArchetype,
    this.secondaryArchetype,
    required this.explorerScore,
    required this.albumListenerScore,
    required this.artistLoyalistScore,
    required this.catalogExplorerScore,
    required this.discoveryRatio,
    required this.completionTendency,
    required this.repeatTendency,
    required this.topGenre,
    required this.topArtist,
    required this.topAlbum,
    required this.peakListeningHour,
    required this.averageSessionMinutes,
    required this.computedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'primaryArchetype': primaryArchetype,
      'secondaryArchetype': secondaryArchetype,
      'explorerScore': explorerScore,
      'albumListenerScore': albumListenerScore,
      'artistLoyalistScore': artistLoyalistScore,
      'catalogExplorerScore': catalogExplorerScore,
      'discoveryRatio': discoveryRatio,
      'completionTendency': completionTendency,
      'repeatTendency': repeatTendency,
      'topGenre': topGenre,
      'topArtist': topArtist,
      'topAlbum': topAlbum,
      'peakListeningHour': peakListeningHour,
      'averageSessionMinutes': averageSessionMinutes,
      'computedAt': computedAt.toIso8601String(),
    };
  }

  factory TasteProfile.fromMap(Map<dynamic, dynamic> map) {
    return TasteProfile(
      primaryArchetype: map['primaryArchetype'] as String? ?? 'Explorer',
      secondaryArchetype: map['secondaryArchetype'] as String?,
      explorerScore: (map['explorerScore'] as num?)?.toDouble() ?? 0.0,
      albumListenerScore: (map['albumListenerScore'] as num?)?.toDouble() ?? 0.0,
      artistLoyalistScore: (map['artistLoyalistScore'] as num?)?.toDouble() ?? 0.0,
      catalogExplorerScore: (map['catalogExplorerScore'] as num?)?.toDouble() ?? 0.0,
      discoveryRatio: (map['discoveryRatio'] as num?)?.toDouble() ?? 0.0,
      completionTendency: (map['completionTendency'] as num?)?.toDouble() ?? 0.0,
      repeatTendency: (map['repeatTendency'] as num?)?.toDouble() ?? 0.0,
      topGenre: map['topGenre'] as String? ?? 'Unknown',
      topArtist: map['topArtist'] as String? ?? 'Unknown',
      topAlbum: map['topAlbum'] as String? ?? 'Unknown',
      peakListeningHour: (map['peakListeningHour'] as num?)?.toInt() ?? 12,
      averageSessionMinutes: (map['averageSessionMinutes'] as num?)?.toInt() ?? 0,
      computedAt: map['computedAt'] != null
          ? DateTime.tryParse(map['computedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
