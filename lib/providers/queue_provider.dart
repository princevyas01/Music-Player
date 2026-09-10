import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/queue_item_model.dart';
import '../models/track_model.dart';
import '../services/queue_service.dart';
import 'audio_provider.dart';

class QueueState {
  final List<QueueItem> items;
  final int currentIndex;
  final bool isShuffleEnabled;

  const QueueState({
    this.items = const [],
    this.currentIndex = -1,
    this.isShuffleEnabled = false,
  });

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < items.length
          ? items[currentIndex].track
          : null;

  List<QueueItem> get upcoming =>
      items.skip(currentIndex < 0 ? 0 : currentIndex + 1).toList(growable: false);
}

class QueueNotifier extends StateNotifier<QueueState> {
  final QueueService _service;
  final AudioNotifier _audioNotifier;
  final List<StreamSubscription<void>> _subscriptions = [];

  QueueNotifier(this._service, this._audioNotifier) : super(const QueueState()) {
    _subscriptions.add(_service.changes.listen((_) => refresh()));
    refresh();
  }

  void refresh({bool isShuffleEnabled = false}) {
    state = QueueState(
      items: _service.items,
      currentIndex: _service.currentIndex,
      isShuffleEnabled: isShuffleEnabled,
    );
  }

  Future<void> addToEnd(Track track) async {
    await _service.addToEnd(track);
    refresh();
  }

  Future<void> playNext(Track track) async {
    await _service.playNext(track);
    refresh();
  }

  Future<bool> playAt(int index) async {
    final changed = await _audioNotifier.playQueueItem(index);
    refresh();
    return changed;
  }

  Future<bool> removeAt(int index) async {
    final changed = await _service.removeAt(index);
    refresh();
    return changed;
  }

  Future<bool> move(int fromIndex, int toIndex) async {
    final changed = await _service.move(fromIndex, toIndex);
    refresh();
    return changed;
  }

  Future<void> clearUpcoming() async {
    await _service.clearUpcoming();
    refresh();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

final queueServiceProvider = Provider<QueueService>((ref) {
  return QueueService(ref.watch(audioHandlerProvider));
});

final queueProvider = StateNotifierProvider<QueueNotifier, QueueState>((ref) {
  final notifier = QueueNotifier(
    ref.watch(queueServiceProvider),
    ref.read(audioProvider.notifier),
  );
  ref.listen(audioProvider, (_, next) {
    notifier.refresh(isShuffleEnabled: next.isShuffleEnabled);
  });
  return notifier;
});
