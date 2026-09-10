import '../models/listening_session_model.dart';
import 'storage_service.dart';

/// Aggregates listening events into a single session after a 30-minute gap.
/// It consumes events from the existing player/history path; it never records
/// a second set of per-track statistics.
class SessionService {
  static const inactivityGap = Duration(minutes: 30);
  ListeningSession? _active;
  DateTime? _lastActivityAt;

  ListeningSession? get activeSession => _active;

  Future<void> recordTrackStarted(String trackId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    if (_active == null ||
        (_lastActivityAt != null && now.difference(_lastActivityAt!) >= inactivityGap)) {
      await end(at: _lastActivityAt);
      _active = ListeningSession(
        sessionId: 'session-${now.microsecondsSinceEpoch}',
        startedAt: now,
        endedAt: now,
        durationMs: 0,
        tracksStarted: 1,
        trackIds: [trackId],
      );
    } else {
      final ids = List<String>.from(_active!.trackIds);
      if (ids.isEmpty || ids.last != trackId) ids.add(trackId);
      _active = _active!.copyWith(
        endedAt: now,
        tracksStarted: _active!.tracksStarted + 1,
        trackIds: ids,
      );
    }
    _lastActivityAt = now;
  }

  void recordListenProgress(int deltaMs, {DateTime? at}) {
    if (_active == null || deltaMs <= 0) return;
    final now = at ?? DateTime.now();
    _active = _active!.copyWith(
      endedAt: now,
      durationMs: _active!.durationMs + deltaMs,
    );
    _lastActivityAt = now;
  }

  void recordTrackCompleted({DateTime? at}) {
    if (_active == null) return;
    final now = at ?? DateTime.now();
    _active = _active!.copyWith(
      endedAt: now,
      tracksCompleted: _active!.tracksCompleted + 1,
    );
    _lastActivityAt = now;
  }

  void recordTrackSkipped({DateTime? at}) {
    if (_active == null) return;
    final now = at ?? DateTime.now();
    _active = _active!.copyWith(
      endedAt: now,
      tracksSkipped: _active!.tracksSkipped + 1,
    );
    _lastActivityAt = now;
  }

  Future<ListeningSession?> end({DateTime? at}) async {
    final session = _active;
    if (session == null) return null;
    final closed = session.copyWith(endedAt: at ?? session.endedAt);
    _active = null;
    _lastActivityAt = null;
    await StorageService.saveListeningSession(closed);
    return closed;
  }
}
