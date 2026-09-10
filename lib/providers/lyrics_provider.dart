import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lyrics_model.dart';
import '../models/track_model.dart';
import '../services/lyrics_service.dart';
import 'audio_provider.dart';

class LyricsState {
  final String? trackId;
  final ParsedLyrics? lyrics;
  final int currentLineIndex;
  final bool isLoading;

  const LyricsState({
    this.trackId,
    this.lyrics,
    this.currentLineIndex = -1,
    this.isLoading = false,
  });
}

class LyricsNotifier extends StateNotifier<LyricsState> {
  final LyricsService _service;
  final LyricsParser _parser;

  LyricsNotifier(this._service, this._parser) : super(const LyricsState());

  Future<void> load(Track track) async {
    if (state.trackId == track.id && state.lyrics != null) return;
    state = LyricsState(trackId: track.id, isLoading: true);
    final lyrics = await _service.loadForTrack(track);
    // Ignore a stale disk read after the UI moves to another track.
    if (state.trackId != track.id) return;
    state = LyricsState(trackId: track.id, lyrics: lyrics);
  }

  void updatePosition(String trackId, Duration position) {
    final lyrics = state.lyrics;
    if (state.trackId != trackId || lyrics == null || !lyrics.isSynced) return;
    final index = _parser.currentLineIndex(lyrics, position);
    if (index != state.currentLineIndex) {
      state = LyricsState(
        trackId: state.trackId,
        lyrics: lyrics,
        currentLineIndex: index,
      );
    }
  }
}

final lyricsServiceProvider = Provider<LyricsService>((ref) => LyricsService());

final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>((ref) {
  final notifier = LyricsNotifier(ref.watch(lyricsServiceProvider), const LyricsParser());
  ref.listen<PlaybackStateData>(audioProvider, (_, next) {
    final track = next.currentTrack;
    if (track != null) notifier.updatePosition(track.id, next.position);
  });
  return notifier;
});
