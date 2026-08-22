import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/track_model.dart';
import 'storage_service.dart';

enum StopMode { none, afterCurrentTrack, afterCurrentAlbum, afterCurrentQueue }

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _subscriptions = [];

  List<Track> _playlist = [];
  int _currentIndex = -1;

  ConcatenatingAudioSource? _audioSource;
  StopMode _stopMode = StopMode.none;
  Timer? _sleepTimer;
  Timer? _fadeTimer;

  AudioPlayerHandler() {
    _initPlayerListeners();
  }

  AudioPlayer get player => _player;
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Track? get currentTrack => (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;
  StopMode get stopMode => _stopMode;

  void _initPlayerListeners() {
    _subscriptions.add(
      _player.playbackEventStream.listen((PlaybackEvent event) {
        final playing = _player.playing;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _currentIndex,
        ));
      }, onError: (Object e, StackTrace st) {
        debugPrint('AudioPlayerHandler playback event error: $e');
      }),
    );

    _subscriptions.add(
      _player.sequenceStateStream.listen((sequenceState) {
        if (sequenceState == null) return;
        final currentItem = sequenceState.currentSource;
        final tag = currentItem?.tag as MediaItem?;
        if (tag != null) {
          mediaItem.add(tag);
          final oldIndex = _currentIndex;
          final foundIndex = _playlist.indexWhere((t) => t.id == tag.id);
          if (foundIndex != -1) {
            _currentIndex = foundIndex;
          } else {
            _currentIndex = sequenceState.currentIndex;
          }

          // Handle Stop Modes on track change
          if (oldIndex >= 0 && oldIndex != _currentIndex) {
            _checkStopModeOnTrackChange(oldIndex, _currentIndex);
          }

          _persistQueueState();
        }
      }),
    );

    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (_stopMode == StopMode.afterCurrentQueue) {
            pause();
            _stopMode = StopMode.none;
          }
        }
      }),
    );
  }

  void setStopMode(StopMode mode) {
    _stopMode = mode;
  }

  void _checkStopModeOnTrackChange(int oldIndex, int newIndex) {
    if (_stopMode == StopMode.afterCurrentTrack) {
      _stopMode = StopMode.none;
      pause();
      return;
    }

    if (_stopMode == StopMode.afterCurrentAlbum && oldIndex >= 0 && oldIndex < _playlist.length && newIndex < _playlist.length) {
      final oldAlbum = _playlist[oldIndex].album;
      final newAlbum = _playlist[newIndex].album;
      if (oldAlbum != newAlbum) {
        _stopMode = StopMode.none;
        pause();
      }
    }
  }

  AudioSource _createAudioSource(Track track) {
    final tag = MediaItem(
      id: track.id,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: Duration(milliseconds: track.durationMs),
      artUri: track.artworkUri != null ? Uri.parse(track.artworkUri!) : null,
    );
    if (track.filePath.startsWith('asset:///')) {
      return AudioSource.uri(Uri.parse(track.filePath), tag: tag);
    } else if (track.filePath.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(track.filePath), tag: tag);
    } else {
      return AudioSource.uri(Uri.file(track.filePath), tag: tag);
    }
  }

  Future<void> setQueueAndPlay(List<Track> tracks, int initialIndex) async {
    if (tracks.isEmpty) return;
    _playlist = List.from(tracks);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);

    final sources = _playlist.map((t) => _createAudioSource(t)).toList();
    _audioSource = ConcatenatingAudioSource(children: sources);

    try {
      await _player.setAudioSource(_audioSource!, initialIndex: _currentIndex, initialPosition: Duration.zero);
      await _player.setSpeed(StorageService.getPlaybackSpeed());
      await _player.play();
      _persistQueueState();
    } catch (e) {
      debugPrint('AudioPlayerHandler setQueueAndPlay error: $e');
    }
  }

  Future<void> restoreQueue(List<Track> tracks, int initialIndex, Duration position) async {
    if (tracks.isEmpty) return;
    _playlist = List.from(tracks);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);

    final sources = _playlist.map((t) => _createAudioSource(t)).toList();
    _audioSource = ConcatenatingAudioSource(children: sources);

    try {
      await _player.setAudioSource(_audioSource!, initialIndex: _currentIndex, initialPosition: position);
      await _player.setSpeed(StorageService.getPlaybackSpeed());
      final saved = StorageService.getSavedQueueState();
      if (saved != null) {
        if (saved['isShuffleEnabled'] == true) {
          await _player.setShuffleModeEnabled(true);
        }
        if (saved['loopMode'] != null) {
          final mode = LoopMode.values.firstWhere((e) => e.name == saved['loopMode'], orElse: () => LoopMode.off);
          await _player.setLoopMode(mode);
        }
      }
    } catch (e) {
      debugPrint('AudioPlayerHandler restoreQueue error: $e');
    }
  }

  Future<void> playNext(Track track) async {
    if (_playlist.isEmpty || _audioSource == null) {
      await setQueueAndPlay([track], 0);
      return;
    }

    final insertIndex = (_currentIndex + 1).clamp(0, _playlist.length);
    _playlist.insert(insertIndex, track);
    await _audioSource!.insert(insertIndex, _createAudioSource(track));
    _persistQueueState();
  }

  Future<void> addToQueue(Track track) async {
    if (_playlist.isEmpty || _audioSource == null) {
      await setQueueAndPlay([track], 0);
      return;
    }

    _playlist.add(track);
    await _audioSource!.add(_createAudioSource(track));
    _persistQueueState();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await StorageService.setPlaybackSpeed(speed);
    await _player.setSpeed(speed);
  }

  void startSleepTimer(int minutes, {int fadeOutSeconds = 0}) {
    cancelSleepTimer();
    if (minutes <= 0) return;

    final duration = Duration(minutes: minutes);
    _sleepTimer = Timer(duration, () async {
      if (fadeOutSeconds > 0) {
        await _performFadeOut(fadeOutSeconds);
      }
      await pause();
      await _player.setVolume(1.0); // Reset volume after pause
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _player.setVolume(1.0);
  }

  Future<void> _performFadeOut(int fadeOutSeconds) async {
    const steps = 10;
    final stepDurationMs = (fadeOutSeconds * 1000) ~/ steps;
    for (int i = steps; i >= 0; i--) {
      final vol = i / steps;
      await _player.setVolume(vol);
      await Future.delayed(Duration(milliseconds: stepDurationMs));
    }
  }

  void _persistQueueState() {
    if (_playlist.isEmpty) return;
    StorageService.saveQueueState(
      queueTrackIds: _playlist.map((t) => t.id).toList(),
      currentIndex: _currentIndex,
      positionMs: _player.position.inMilliseconds,
      isShuffleEnabled: _player.shuffleModeEnabled,
      loopMode: _player.loopMode.name,
    );
  }

  @override
  Future<void> play() async => await _player.play();

  @override
  Future<void> pause() async {
    await _player.pause();
    _persistQueueState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _persistQueueState();
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      _currentIndex = _player.currentIndex ?? 0;
    } else if (_player.loopMode == LoopMode.all && _playlist.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
      _currentIndex = 0;
    }
    _persistQueueState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      _currentIndex = _player.currentIndex ?? 0;
    } else if (_player.loopMode == LoopMode.all && _playlist.isNotEmpty) {
      await _player.seek(Duration.zero, index: _playlist.length - 1);
      _currentIndex = _playlist.length - 1;
    } else {
      await _player.seek(Duration.zero);
    }
    _persistQueueState();
  }

  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(enable);
    _persistQueueState();
  }

  Future<void> toggleRepeat() async {
    final currentMode = _player.loopMode;
    final nextMode = currentMode == LoopMode.off
        ? LoopMode.one
        : currentMode == LoopMode.one
            ? LoopMode.all
            : LoopMode.off;
    await _player.setLoopMode(nextMode);
    _persistQueueState();
  }

  Future<void> disposeHandler() async {
    cancelSleepTimer();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
  }
}
