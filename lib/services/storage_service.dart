import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/hive_boxes.dart';
import '../models/track_model.dart';
import '../models/playlist_model.dart';
import '../models/favorite_model.dart';
import '../models/history_model.dart';
import '../models/metadata_override_model.dart';
import '../models/feature_flags_model.dart';
import '../models/audio_effect_settings_model.dart';
import '../models/playlist_folder_model.dart';
import '../models/smart_playlist_rule_model.dart';
import '../models/listening_session_model.dart';
import '../models/scheduled_playback_model.dart';
import '../models/cloud_sync_model.dart';
import '../models/artwork_model.dart';

class StorageService {
  static Future<void> init() async {
    await Hive.initFlutter();

    // Core original boxes
    await Hive.openBox(HiveBoxes.tracks);
    await Hive.openBox(HiveBoxes.playlists);
    await Hive.openBox(HiveBoxes.favorites);
    await Hive.openBox(HiveBoxes.settings);
    await Hive.openBox(HiveBoxes.history);
    await Hive.openBox(HiveBoxes.metadataOverrides);
    await Hive.openBox(HiveBoxes.queueState);

    // New domain boxes opened safely with isolation
    final newBoxes = [
      HiveBoxes.artworkCache,
      HiveBoxes.waveformCache,
      HiveBoxes.lyrics,
      HiveBoxes.sessions,
      HiveBoxes.recommendationCache,
      HiveBoxes.smartRules,
      HiveBoxes.audioEffects,
      HiveBoxes.scheduledPlayback,
      HiveBoxes.sync,
      HiveBoxes.playlistFolders,
    ];

    for (final boxName in newBoxes) {
      try {
        await Hive.openBox(boxName);
      } catch (e) {
        debugPrint('StorageService: Non-fatal error opening box ' + boxName + ': ' + e.toString());
      }
    }
  }

  // Helper box accessor
  static Box? _getOpenBox(String name) {
    return Hive.isBoxOpen(name) ? Hive.box(name) : null;
  }

  // ---------- Tracks ----------
  static List<Track> getSavedTracks() {
    final box = _getOpenBox(HiveBoxes.tracks);
    if (box == null) return [];

    final overrides = getMetadataOverridesMap();
    final rawTracks = box.values.map((item) => Track.fromMap(item as Map)).toList();
    if (overrides.isEmpty) return rawTracks;

    return rawTracks.map((track) {
      final override = overrides[track.id];
      if (override == null) return track;
      return track.copyWith(
        title: override.title ?? track.title,
        artist: override.artist ?? track.artist,
        album: override.album ?? track.album,
        genre: override.genre ?? track.genre,
        year: override.year ?? track.year,
        trackNumber: override.trackNumber ?? track.trackNumber,
        discNumber: override.discNumber ?? track.discNumber,
      );
    }).toList();
  }

  static Future<void> saveTracks(List<Track> tracks) async {
    final box = _getOpenBox(HiveBoxes.tracks);
    if (box == null) return;
    final Map<String, dynamic> trackMap = {
      for (var t in tracks) t.id: t.toMap()
    };
    await box.putAll(trackMap);
  }

  static Future<void> clearTracks() async {
    final box = _getOpenBox(HiveBoxes.tracks);
    await box?.clear();
  }

  // ---------- Playlists ----------
  static List<Playlist> getPlaylists() {
    final box = _getOpenBox(HiveBoxes.playlists);
    if (box == null) return [];
    return box.values.map((item) => Playlist.fromMap(item as Map)).toList();
  }

  static Future<void> savePlaylist(Playlist playlist) async {
    final box = _getOpenBox(HiveBoxes.playlists);
    await box?.put(playlist.id, playlist.toMap());
  }

  static Future<void> savePlaylists(List<Playlist> playlists) async {
    final box = _getOpenBox(HiveBoxes.playlists);
    if (box == null) return;
    final Map<String, dynamic> pMap = {for (var p in playlists) p.id: p.toMap()};
    await box.putAll(pMap);
  }

  static Future<void> deletePlaylist(String playlistId) async {
    final box = _getOpenBox(HiveBoxes.playlists);
    await box?.delete(playlistId);
  }

  // ---------- Favorites ----------
  static Set<String> getFavoriteTrackIds() {
    final box = _getOpenBox(HiveBoxes.favorites);
    if (box == null) return {};
    final favorites = box.values.map((item) => Favorite.fromMap(item as Map)).toList();
    return favorites.map((f) => f.trackId).toSet();
  }

  static Future<void> toggleFavorite(String trackId) async {
    final box = _getOpenBox(HiveBoxes.favorites);
    if (box == null) return;
    final set = getFavoriteTrackIds();
    if (set.contains(trackId)) {
      await box.delete(trackId);
    } else {
      final fav = Favorite(trackId: trackId, addedAt: DateTime.now());
      await box.put(trackId, fav.toMap());
    }
  }

  static Future<void> setFavoriteTrackIds(Set<String> trackIds) async {
    final box = _getOpenBox(HiveBoxes.favorites);
    if (box == null) return;
    await box.clear();
    final Map<String, dynamic> favMap = {
      for (var id in trackIds) id: Favorite(trackId: id, addedAt: DateTime.now()).toMap()
    };
    await box.putAll(favMap);
  }

  // ---------- History ----------
  static Map<String, PlaybackHistory> getHistoryMap() {
    final box = _getOpenBox(HiveBoxes.history);
    if (box == null) return {};
    final Map<String, PlaybackHistory> map = {};
    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        map[key.toString()] = PlaybackHistory.fromMap(val);
      }
    }
    return map;
  }

  static Future<void> saveHistoryItem(PlaybackHistory history) async {
    final box = _getOpenBox(HiveBoxes.history);
    await box?.put(history.trackId, history.toMap());
  }

  static Future<void> saveAllHistory(Map<String, PlaybackHistory> historyMap) async {
    final box = _getOpenBox(HiveBoxes.history);
    if (box == null) return;
    final Map<String, dynamic> rawMap = {
      for (var entry in historyMap.entries) entry.key: entry.value.toMap()
    };
    await box.putAll(rawMap);
  }

  // ---------- Metadata Overrides ----------
  static Map<String, MetadataOverride> getMetadataOverridesMap() {
    final box = _getOpenBox(HiveBoxes.metadataOverrides);
    if (box == null) return {};
    final Map<String, MetadataOverride> map = {};
    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        map[key.toString()] = MetadataOverride.fromMap(val);
      }
    }
    return map;
  }

  static Future<void> saveMetadataOverride(MetadataOverride override) async {
    final box = _getOpenBox(HiveBoxes.metadataOverrides);
    await box?.put(override.trackId, override.toMap());
  }

  static Future<void> deleteMetadataOverride(String trackId) async {
    final box = _getOpenBox(HiveBoxes.metadataOverrides);
    await box?.delete(trackId);
  }

  // ---------- Queue State ----------
  static Map<String, dynamic>? getSavedQueueState() {
    final box = _getOpenBox(HiveBoxes.queueState);
    if (box == null) return null;
    final raw = box.get('state');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> saveQueueState({
    required List<String> queueTrackIds,
    required int currentIndex,
    required int positionMs,
    required bool isShuffleEnabled,
    required String loopMode,
  }) async {
    final box = _getOpenBox(HiveBoxes.queueState);
    await box?.put('state', {
      'queueTrackIds': queueTrackIds,
      'currentIndex': currentIndex,
      'positionMs': positionMs,
      'isShuffleEnabled': isShuffleEnabled,
      'loopMode': loopMode,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ---------- Settings & Preferences ----------
  static bool isDarkMode() {
    final box = _getOpenBox(HiveBoxes.settings);
    if (box == null) return true;
    return box.get('isDarkMode', defaultValue: true) as bool;
  }

  static Future<void> setDarkMode(bool isDark) async {
    final box = _getOpenBox(HiveBoxes.settings);
    await box?.put('isDarkMode', isDark);
  }

  static String getSortOption() {
    final box = _getOpenBox(HiveBoxes.settings);
    if (box == null) return 'dateAdded';
    return box.get('sortOption', defaultValue: 'dateAdded') as String;
  }

  static Future<void> setSortOption(String sortOption) async {
    final box = _getOpenBox(HiveBoxes.settings);
    await box?.put('sortOption', sortOption);
  }

  static int getShortTrackThresholdSeconds() {
    final box = _getOpenBox(HiveBoxes.settings);
    if (box == null) return 8;
    return (box.get('shortTrackThreshold', defaultValue: 8) as num).toInt();
  }

  static Future<void> setShortTrackThresholdSeconds(int seconds) async {
    final box = _getOpenBox(HiveBoxes.settings);
    await box?.put('shortTrackThreshold', seconds);
  }

  static double getPlaybackSpeed() {
    final box = _getOpenBox(HiveBoxes.settings);
    if (box == null) return 1.0;
    return (box.get('playbackSpeed', defaultValue: 1.0) as num).toDouble();
  }

  static Future<void> setPlaybackSpeed(double speed) async {
    final box = _getOpenBox(HiveBoxes.settings);
    await box?.put('playbackSpeed', speed);
  }

  static int getSleepTimerMinutes() {
    final box = _getOpenBox(HiveBoxes.settings);
    if (box == null) return 0;
    return (box.get('sleepTimerMinutes', defaultValue: 0) as num).toInt();
  }

  static Future<void> setSleepTimerMinutes(int minutes) async {
    final box = _getOpenBox(HiveBoxes.settings);
    await box?.put('sleepTimerMinutes', minutes);
  }

  static int getSleepFadeOutSeconds() {
    final box = _getOpenBox(HiveBoxes.settings);
    if (box == null) return 0;
    return (box.get('sleepFadeOutSeconds', defaultValue: 0) as num).toInt();
  }

  static Future<void> setSleepFadeOutSeconds(int seconds) async {
    final box = _getOpenBox(HiveBoxes.settings);
    await box?.put('sleepFadeOutSeconds', seconds);
  }

  // ---------- Internal Feature Flags ----------
  static FeatureFlags getFeatureFlags() {
    final box = _getOpenBox(HiveBoxes.settings);
    if (box == null) return const FeatureFlags();
    final raw = box.get('featureFlags');
    if (raw is Map) return FeatureFlags.fromMap(raw);
    return const FeatureFlags();
  }

  static Future<void> setFeatureFlags(FeatureFlags flags) async {
    final box = _getOpenBox(HiveBoxes.settings);
    await box?.put('featureFlags', flags.toMap());
  }

  // ---------- Audio Effects Settings ----------
  static AudioEffectSettings getAudioEffectSettings() {
    final box = _getOpenBox(HiveBoxes.audioEffects);
    if (box == null) return const AudioEffectSettings();
    final raw = box.get('settings');
    if (raw is Map) return AudioEffectSettings.fromMap(raw);
    return const AudioEffectSettings();
  }

  static Future<void> setAudioEffectSettings(AudioEffectSettings settings) async {
    final box = _getOpenBox(HiveBoxes.audioEffects);
    await box?.put('settings', settings.toMap());
  }

  // ---------- Playlist Folders ----------
  static List<PlaylistFolder> getPlaylistFolders() {
    final box = _getOpenBox(HiveBoxes.playlistFolders);
    if (box == null) return [];
    return box.values.map((item) => PlaylistFolder.fromMap(item as Map)).toList();
  }

  static Future<void> savePlaylistFolder(PlaylistFolder folder) async {
    final box = _getOpenBox(HiveBoxes.playlistFolders);
    await box?.put(folder.id, folder.toMap());
  }

  static Future<void> savePlaylistFolders(List<PlaylistFolder> folders) async {
    final box = _getOpenBox(HiveBoxes.playlistFolders);
    if (box == null) return;
    final map = {for (var f in folders) f.id: f.toMap()};
    await box.putAll(map);
  }

  static Future<void> deletePlaylistFolder(String folderId) async {
    final box = _getOpenBox(HiveBoxes.playlistFolders);
    await box?.delete(folderId);
  }

  // ---------- Smart Playlist Definitions ----------
  static List<SmartPlaylistDefinition> getSmartPlaylistDefinitions() {
    final box = _getOpenBox(HiveBoxes.smartRules);
    if (box == null) return [];
    return box.values.map((item) => SmartPlaylistDefinition.fromMap(item as Map)).toList();
  }

  static Future<void> saveSmartPlaylistDefinition(SmartPlaylistDefinition def) async {
    final box = _getOpenBox(HiveBoxes.smartRules);
    await box?.put(def.id, def.toMap());
  }

  static Future<void> deleteSmartPlaylistDefinition(String id) async {
    final box = _getOpenBox(HiveBoxes.smartRules);
    await box?.delete(id);
  }

  // ---------- Listening Sessions ----------
  static List<ListeningSession> getListeningSessions() {
    final box = _getOpenBox(HiveBoxes.sessions);
    if (box == null) return [];
    return box.values.map((item) => ListeningSession.fromMap(item as Map)).toList();
  }

  static Future<void> saveListeningSession(ListeningSession session) async {
    final box = _getOpenBox(HiveBoxes.sessions);
    await box?.put(session.sessionId, session.toMap());
  }

  // ---------- Scheduled Playback Items ----------
  static List<ScheduledPlaybackItem> getScheduledPlaybackItems() {
    final box = _getOpenBox(HiveBoxes.scheduledPlayback);
    if (box == null) return [];
    return box.values.map((item) => ScheduledPlaybackItem.fromMap(item as Map)).toList();
  }

  static Future<void> saveScheduledPlaybackItem(ScheduledPlaybackItem item) async {
    final box = _getOpenBox(HiveBoxes.scheduledPlayback);
    await box?.put(item.id, item.toMap());
  }

  static Future<void> deleteScheduledPlaybackItem(String id) async {
    final box = _getOpenBox(HiveBoxes.scheduledPlayback);
    await box?.delete(id);
  }

  // ---------- Cloud Sync Records ----------
  static List<SyncRecord> getSyncRecords(String domain) {
    final box = _getOpenBox(HiveBoxes.sync);
    if (box == null) return [];
    return box.values
        .where((item) => item is Map && item['domain'] == domain)
        .map((item) => SyncRecord.fromMap(item as Map))
        .toList();
  }

  static Future<void> saveSyncRecord(SyncRecord record) async {
    final box = _getOpenBox(HiveBoxes.sync);
    await box?.put(record.recordId, record.toMap());
  }

  // ---------- Waveform & Lyrics Cache Helpers ----------
  static String? getCachedLyrics(String trackId) {
    final box = _getOpenBox(HiveBoxes.lyrics);
    return box?.get(trackId) as String?;
  }

  static Future<void> cacheLyrics(String trackId, String rawLyrics) async {
    final box = _getOpenBox(HiveBoxes.lyrics);
    await box?.put(trackId, rawLyrics);
  }

  static List<double>? getCachedWaveform(String trackId) {
    final box = _getOpenBox(HiveBoxes.waveformCache);
    final raw = box?.get(trackId);
    if (raw is List) {
      return raw.map((e) => (e as num).toDouble()).toList();
    }
    return null;
  }

  static Future<void> cacheWaveform(String trackId, List<double> amplitudes) async {
    final box = _getOpenBox(HiveBoxes.waveformCache);
    await box?.put(trackId, amplitudes);
  }

  // ---------- Artwork Cache References ----------
  static ArtworkModel? getCachedArtwork(String trackId) {
    final box = _getOpenBox(HiveBoxes.artworkCache);
    final raw = box?.get(trackId);
    return raw is Map ? ArtworkModel.fromMap(raw) : null;
  }

  static Future<void> cacheArtwork(ArtworkModel artwork) async {
    final box = _getOpenBox(HiveBoxes.artworkCache);
    await box?.put(artwork.trackId, artwork.toMap());
  }

  // ---------- Backup & Atomic Restore (Schema Version 2) ----------
  static String exportBackupJson() {
    final backup = {
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'SpinWave',
      'favorites': getFavoriteTrackIds().toList(),
      'playlists': getPlaylists().map((p) => p.toMap()).toList(),
      'history': getHistoryMap().map((k, v) => MapEntry(k, v.toMap())),
      'metadataOverrides': getMetadataOverridesMap().map((k, v) => MapEntry(k, v.toMap())),
      'settings': {
        'isDarkMode': isDarkMode(),
        'sortOption': getSortOption(),
        'shortTrackThreshold': getShortTrackThresholdSeconds(),
        'playbackSpeed': getPlaybackSpeed(),
      },
      'playlistFolders': getPlaylistFolders().map((f) => f.toMap()).toList(),
      'smartRules': getSmartPlaylistDefinitions().map((s) => s.toMap()).toList(),
      'audioEffects': getAudioEffectSettings().toMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  static Future<bool> restoreBackupJson(String jsonStr) async {
    try {
      final map = jsonDecode(jsonStr);
      if (map is! Map) return false;

      final schemaVersion = (map['schemaVersion'] as num?)?.toInt() ?? 0;
      if (schemaVersion < 1) {
        debugPrint('StorageService: Unsupported backup schema version ' + schemaVersion.toString());
        return false;
      }

      final favoritesList = (map['favorites'] as List?)?.cast<String>() ?? [];
      final playlistsRaw = (map['playlists'] as List?) ?? [];
      final historyRaw = (map['history'] as Map?) ?? {};
      final overridesRaw = (map['metadataOverrides'] as Map?) ?? {};
      final settingsRaw = (map['settings'] as Map?) ?? {};

      final playlists = playlistsRaw.map((p) => Playlist.fromMap(p as Map)).toList();
      final historyMap = <String, PlaybackHistory>{};
      historyRaw.forEach((k, v) {
        if (v is Map) historyMap[k.toString()] = PlaybackHistory.fromMap(v);
      });

      final overridesMap = <String, MetadataOverride>{};
      overridesRaw.forEach((k, v) {
        if (v is Map) overridesMap[k.toString()] = MetadataOverride.fromMap(v);
      });

      await setFavoriteTrackIds(favoritesList.toSet());

      // Clear existing playlists before restoring to remove stale entries
      final playlistsBox = _getOpenBox(HiveBoxes.playlists);
      if (playlistsBox != null) await playlistsBox.clear();
      await savePlaylists(playlists);

      // Clear existing history before restoring to remove stale entries
      final historyBox = _getOpenBox(HiveBoxes.history);
      if (historyBox != null) await historyBox.clear();
      await saveAllHistory(historyMap);

      final overridesBox = _getOpenBox(HiveBoxes.metadataOverrides);
      if (overridesBox != null) {
        await overridesBox.clear();
        for (var entry in overridesMap.entries) {
          await overridesBox.put(entry.key, entry.value.toMap());
        }
      }

      if (settingsRaw.containsKey('isDarkMode')) {
        await setDarkMode(settingsRaw['isDarkMode'] as bool);
      }
      if (settingsRaw.containsKey('sortOption')) {
        await setSortOption(settingsRaw['sortOption'] as String);
      }
      if (settingsRaw.containsKey('shortTrackThreshold')) {
        await setShortTrackThresholdSeconds((settingsRaw['shortTrackThreshold'] as num).toInt());
      }
      if (settingsRaw.containsKey('playbackSpeed')) {
        await setPlaybackSpeed((settingsRaw['playbackSpeed'] as num).toDouble());
      }

      // Schema v2 optional extensions - restored safely when present
      if (map.containsKey('playlistFolders')) {
        final foldersRaw = (map['playlistFolders'] as List?) ?? [];
        final folders = foldersRaw.map((f) => PlaylistFolder.fromMap(f as Map)).toList();
        final folderBox = _getOpenBox(HiveBoxes.playlistFolders);
        if (folderBox != null) {
          await folderBox.clear();
          await savePlaylistFolders(folders);
        }
      }

      if (map.containsKey('smartRules')) {
        final rulesRaw = (map['smartRules'] as List?) ?? [];
        final smartRulesBox = _getOpenBox(HiveBoxes.smartRules);
        if (smartRulesBox != null) {
          await smartRulesBox.clear();
          for (var r in rulesRaw) {
            if (r is Map) {
              final def = SmartPlaylistDefinition.fromMap(r);
              await saveSmartPlaylistDefinition(def);
            }
          }
        }
      }

      if (map.containsKey('audioEffects') && map['audioEffects'] is Map) {
        final effects = AudioEffectSettings.fromMap(map['audioEffects'] as Map);
        await setAudioEffectSettings(effects);
      }

      return true;
    } catch (e, st) {
      debugPrint('StorageService restoreBackupJson failed: ' + e.toString() + '\n' + st.toString());
      return false;
    }
  }
}
