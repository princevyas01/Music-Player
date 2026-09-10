import 'dart:async';
import '../models/playlist_model.dart';
import '../models/queue_item_model.dart';
import '../models/track_model.dart';
import 'audio_player_handler.dart';
import 'storage_service.dart';

/// Read/write coordination for the user-facing queue.
///
/// AudioPlayerHandler remains the only playback and persistence authority.
/// This service deliberately contains no second queue or player state.
class QueueService {
  final AudioPlayerHandler _handler;

  QueueService(this._handler);

  List<Track> get tracks => _handler.playlist;
  int get currentIndex => _handler.currentIndex;
  Track? get currentTrack => _handler.currentTrack;

  /// Emits after native sequence changes, including notification and headset
  /// controls that bypass the in-app queue UI.
  Stream<void> get changes =>
      _handler.player.sequenceStateStream.map<void>((_) {});

  List<QueueItem> get items => List<QueueItem>.generate(
        _handler.playlist.length,
        (index) {
          final track = _handler.playlist[index];
          return QueueItem(
            // A positional identifier remains unique for repeated tracks.
            queueId: '$index:${track.id}:${track.filePath}',
            track: track,
            addedAt: DateTime.fromMillisecondsSinceEpoch(0),
          );
        },
        growable: false,
      );

  List<QueueItem> get upcomingItems {
    final start = currentIndex < 0 ? 0 : currentIndex + 1;
    return items.skip(start).toList(growable: false);
  }

  Future<void> playNext(Track track) => _handler.playNext(track);
  Future<void> addToEnd(Track track) => _handler.addToQueue(track);
  Future<bool> playAt(int index) => _handler.playQueueItemAt(index);
  Future<bool> removeAt(int index) => _handler.removeQueueItemAt(index);
  Future<bool> move(int fromIndex, int toIndex) =>
      _handler.moveQueueItem(fromIndex, toIndex);
  Future<void> clearUpcoming() => _handler.clearUpcomingQueue();

  /// Creates an ordinary playlist from the exact logical queue ordering.
  /// This intentionally includes the current item; no audio source changes.
  Future<Playlist?> saveAsPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || tracks.isEmpty) return null;
    final now = DateTime.now();
    final playlist = Playlist(
      id: 'queue-${now.microsecondsSinceEpoch}',
      name: trimmed,
      trackIds: tracks.map((track) => track.id).toList(growable: false),
      createdAt: now,
      updatedAt: now,
    );
    await StorageService.savePlaylist(playlist);
    return playlist;
  }
}
