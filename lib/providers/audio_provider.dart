import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track_model.dart';
import '../services/audio_player_handler.dart';
import '../services/history_service.dart';
import '../services/storage_service.dart';
import '../main.dart';

final historyServiceProvider = ChangeNotifierProvider<HistoryService>((ref) => HistoryService());

final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  return globalAudioHandler;
});

class PlaybackStateData {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isShuffleEnabled;
  final LoopMode loopMode;
  final double playbackSpeed;
  final int sleepTimerMinutes;
  final int sleepFadeOutSeconds;
  final StopMode stopMode;

  PlaybackStateData({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffleEnabled = false,
    this.loopMode = LoopMode.off,
    this.playbackSpeed = 1.0,
    this.sleepTimerMinutes = 0,
    this.sleepFadeOutSeconds = 0,
    this.stopMode = StopMode.none,
  });

  PlaybackStateData copyWith({
    Track? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isShuffleEnabled,
    LoopMode? loopMode,
    double? playbackSpeed,
    int? sleepTimerMinutes,
    int? sleepFadeOutSeconds,
    StopMode? stopMode,
  }) {
    return PlaybackStateData(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      loopMode: loopMode ?? this.loopMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
      sleepFadeOutSeconds: sleepFadeOutSeconds ?? this.sleepFadeOutSeconds,
      stopMode: stopMode ?? this.stopMode,
    );
  }
}

class AudioNotifier extends StateNotifier<PlaybackStateData> {
  final AudioPlayerHandler _handler;
  final HistoryService _historyService;
  final List<StreamSubscription> _subscriptions = [];

  Duration _lastRecordedPosition = Duration.zero;
  bool _restoredQueue = false;
  String? _lastStartedTrackId;
  bool _isManualSkip = false;

  AudioNotifier(this._handler, this._historyService)
      : super(PlaybackStateData(
          playbackSpeed: StorageService.getPlaybackSpeed(),
          sleepTimerMinutes: StorageService.getSleepTimerMinutes(),
          sleepFadeOutSeconds: StorageService.getSleepFadeOutSeconds(),
        )) {
    _initStreams();
  }

  void _initStreams() {
    _subscriptions.add(
      _handler.player.sequenceStateStream.listen((sequenceState) {
        if (sequenceState == null) return;
        final currentSource = sequenceState.currentSource;
        final tag = currentSource?.tag as MediaItem?;
        if (tag != null) {
          final newTrackId = tag.id;
          final currentTrackInState = state.currentTrack;

          final matchingTrack = _handler.playlist.firstWhere(
            (t) => t.id == newTrackId,
            orElse: () => Track(
              id: tag.id,
              title: tag.title,
              artist: tag.artist ?? 'Unknown Artist',
              album: tag.album ?? 'Unknown Album',
              durationMs: tag.duration?.inMilliseconds ?? 0,
              filePath: '',
              dateAdded: DateTime.now(),
            ),
          );

          if (currentTrackInState?.id != matchingTrack.id) {
            final prevTrack = currentTrackInState;

            if (prevTrack != null) {
              if (!_isManualSkip) {
                _historyService.recordTrackCompleted(prevTrack.id);
              }
              _isManualSkip = false;
            }

            _lastRecordedPosition = Duration.zero;
            state = state.copyWith(
              currentTrack: matchingTrack,
              position: Duration.zero,
              duration: Duration(milliseconds: matchingTrack.durationMs),
            );

            if (state.isPlaying && matchingTrack.id != _lastStartedTrackId) {
              _lastStartedTrackId = matchingTrack.id;
              _historyService.recordTrackStart(matchingTrack.id);
            }
          }
        }
      }),
    );

    _subscriptions.add(
      _handler.player.playingStream.listen((playing) {
        final currentTrack = _handler.currentTrack ?? state.currentTrack;
        state = state.copyWith(
          isPlaying: playing,
          currentTrack: currentTrack,
        );
        if (playing && currentTrack != null && currentTrack.id != _lastStartedTrackId) {
          _lastStartedTrackId = currentTrack.id;
          _historyService.recordTrackStart(currentTrack.id);
        }
      }),
    );

    _subscriptions.add(
      _handler.player.positionStream.listen((pos) {
        final dur = state.duration;
        final isNearEnd = dur > Duration.zero && (dur - pos).inMilliseconds < 300;

        if ((pos - state.position).abs() >= const Duration(milliseconds: 250) || pos == Duration.zero || isNearEnd) {
          state = state.copyWith(position: pos);

          if (state.currentTrack != null && state.isPlaying) {
            final delta = (pos - _lastRecordedPosition).inMilliseconds;
            if (delta > 0 && delta < 5000) {
              _historyService.recordPlaybackProgress(state.currentTrack!.id, pos.inMilliseconds, delta);
            }
          }
          _lastRecordedPosition = pos;
        }
      }),
    );

    _subscriptions.add(
      _handler.player.durationStream.listen((dur) {
        if (dur != null && dur != state.duration) {
          state = state.copyWith(duration: dur);
        }
      }),
    );

    _subscriptions.add(
      _handler.player.shuffleModeEnabledStream.listen((shuffle) {
        state = state.copyWith(isShuffleEnabled: shuffle);
      }),
    );

    _subscriptions.add(
      _handler.player.loopModeStream.listen((loop) {
        state = state.copyWith(loopMode: loop);
      }),
    );

    _subscriptions.add(
      _handler.player.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          if (state.currentTrack != null) {
            _historyService.recordTrackCompleted(state.currentTrack!.id);
          }
        }
      }),
    );
  }

  Future<void> restorePersistentQueue(List<Track> allTracks) async {
    if (_restoredQueue || allTracks.isEmpty) return;
    _restoredQueue = true;

    final saved = StorageService.getSavedQueueState();
    if (saved == null) return;

    final List<String> qIds = (saved['queueTrackIds'] as List?)?.cast<String>() ?? [];
    if (qIds.isEmpty) return;

    final trackMap = {for (var t in allTracks) t.id: t};
    final List<Track> qTracks = qIds.where((id) => trackMap.containsKey(id)).map((id) => trackMap[id]!).toList();

    if (qTracks.isEmpty) return;

    final idx = (saved['currentIndex'] as num?)?.toInt() ?? 0;
    final posMs = (saved['positionMs'] as num?)?.toInt() ?? 0;
    final shuffle = (saved['isShuffleEnabled'] as bool?) ?? false;
    final loopName = (saved['loopMode'] as String?) ?? 'off';
    final loop = LoopMode.values.firstWhere((e) => e.name == loopName, orElse: () => LoopMode.off);

    await _handler.restoreQueue(qTracks, idx, Duration(milliseconds: posMs));
    state = state.copyWith(
      currentTrack: _handler.currentTrack,
      position: Duration(milliseconds: posMs),
      duration: Duration(milliseconds: _handler.currentTrack?.durationMs ?? 0),
      isShuffleEnabled: shuffle,
      loopMode: loop,
    );
  }

  Future<void> playTrackList(List<Track> tracks, int initialIndex) async {
    try {
      _isManualSkip = true;
      await _handler.setQueueAndPlay(tracks, initialIndex);
      final ct = _handler.currentTrack;
      state = state.copyWith(
        currentTrack: ct,
        duration: Duration(milliseconds: ct?.durationMs ?? 0),
        position: Duration.zero,
      );
    } catch (e) {
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> playNext(Track track) async {
    await _handler.playNext(track);
    final ct = _handler.currentTrack;
    state = state.copyWith(
      currentTrack: ct,
      duration: Duration(milliseconds: ct?.durationMs ?? 0),
    );
  }

  Future<void> addToQueue(Track track) async {
    await _handler.addToQueue(track);
    final ct = _handler.currentTrack;
    state = state.copyWith(
      currentTrack: ct,
      duration: Duration(milliseconds: ct?.durationMs ?? 0),
    );
  }

  Future<void> togglePlayPause() async {
    if (state.currentTrack == null) return;
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> next() async {
    if (state.currentTrack != null) {
      _isManualSkip = true;
      _historyService.recordTrackSkipped(state.currentTrack!.id);
    }
    await _handler.skipToNext();
    final ct = _handler.currentTrack;
    if (ct != null) {
      state = state.copyWith(
        currentTrack: ct,
        duration: Duration(milliseconds: ct.durationMs),
      );
    }
  }

  Future<void> previous() async {
    _isManualSkip = true;
    await _handler.skipToPrevious();
    final ct = _handler.currentTrack;
    if (ct != null) {
      state = state.copyWith(
        currentTrack: ct,
        duration: Duration(milliseconds: ct.durationMs),
      );
    }
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await _handler.seek(position);
  }

  Future<void> toggleShuffle() async {
    await _handler.toggleShuffle();
  }

  Future<void> toggleRepeat() async {
    await _handler.toggleRepeat();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _handler.setPlaybackSpeed(speed);
  }

  void setSleepTimer(int minutes, {int fadeOutSeconds = 0}) {
    StorageService.setSleepTimerMinutes(minutes);
    StorageService.setSleepFadeOutSeconds(fadeOutSeconds);
    state = state.copyWith(
      sleepTimerMinutes: minutes,
      sleepFadeOutSeconds: fadeOutSeconds,
    );
    _handler.startSleepTimer(minutes, fadeOutSeconds: fadeOutSeconds);
  }

  void setStopMode(StopMode mode) {
    state = state.copyWith(stopMode: mode);
    _handler.setStopMode(mode);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

final audioProvider = StateNotifierProvider<AudioNotifier, PlaybackStateData>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final historyService = ref.read(historyServiceProvider);
  return AudioNotifier(handler, historyService);
});

