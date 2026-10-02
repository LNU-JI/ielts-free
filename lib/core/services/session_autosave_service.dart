/// Session autosave + crash recovery (docs/BRIEF.md §79, PRD Q-8, FR-080).
///
/// A [SessionAutosaveService] owns one `learning_sessions` row and keeps its
/// `checkpoint` JSON up to date while a practice run is in progress:
///
/// - **per-question checkpoint** — call [saveNow] the instant a question is
///   finished so a mid-session kill never loses a submitted question;
/// - **500 ms debounce** — call [checkpoint] for high-frequency draft changes
///   (typing, selecting an option); writes are coalesced to at most one every
///   [debounce] window (PRD Q-8).
///
/// The service never awaits non-database work while a write is in flight and it
/// **cancels its timer in [dispose]**, so no callback can fire after the owning
/// controller is torn down.
library;

import 'dart:async';

import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/enums/session_status.dart';
import 'package:ielts_free/core/models/learning_session.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/utils/id_generator.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Persists a practice run's resumable state.
class SessionAutosaveService {
  SessionAutosaveService({
    required ProgressRepository progressRepository,
    required String userId,
    required RefType sessionType,
    Clock clock = const SystemClock(),
    String? sessionId,
    DateTime? startedAt,
  })  : _progress = progressRepository,
        _userId = userId,
        _sessionType = sessionType,
        _clock = clock,
        _sessionId = sessionId ?? IdGenerator.newSessionId(),
        _startedAt = (startedAt ?? clock.now()).toUtc();

  /// Debounce window for [checkpoint] writes (PRD Q-8).
  static const Duration debounce = Duration(milliseconds: 500);

  final ProgressRepository _progress;
  final String _userId;
  final RefType _sessionType;
  final Clock _clock;
  final String _sessionId;
  final DateTime _startedAt;

  Timer? _timer;
  Map<String, Object?> _pending = const <String, Object?>{};
  int _itemsCompleted = 0;
  bool _disposed = false;
  bool _started = false;

  /// The stable id of this run (used to tag `user_answers.session_id`).
  String get sessionId => _sessionId;

  /// When the run began (UTC).
  DateTime get startedAt => _startedAt;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// Creates (or restores) the `learning_sessions` row as `ACTIVE`.
  ///
  /// [initialCheckpoint] lets a restored run keep its previously saved state.
  Future<void> start({Map<String, Object?> initialCheckpoint = const <String, Object?>{}}) async {
    if (_disposed) {
      return;
    }
    _pending = Map<String, Object?>.of(initialCheckpoint);
    await _write(SessionStatus.active, checkpoint: _pending, itemsCompleted: _itemsCompleted);
    _started = true;
  }

  /// Schedules a debounced checkpoint write (PRD Q-8).
  ///
  /// Repeated calls within [debounce] collapse into a single write of the latest
  /// [data].
  void checkpoint(Map<String, Object?> data) {
    if (_disposed) {
      return;
    }
    _pending = Map<String, Object?>.of(data);
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      // Fire-and-forget: the checkpoint is best-effort; a failure must never
      // crash a live practice session.
      unawaited(_flushPending());
    });
  }

  /// Persists [data] immediately (per-question checkpoint).
  Future<void> saveNow(Map<String, Object?> data, {int? itemsCompleted}) async {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _pending = Map<String, Object?>.of(data);
    if (itemsCompleted != null) {
      _itemsCompleted = itemsCompleted < 0 ? 0 : itemsCompleted;
    }
    await _write(
      SessionStatus.active,
      checkpoint: _pending,
      itemsCompleted: _itemsCompleted,
    );
  }

  /// Marks the run finished and persists the final checkpoint.
  Future<void> complete({
    required int itemsCompleted,
    Map<String, Object?>? checkpoint,
  }) async {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _itemsCompleted = itemsCompleted < 0 ? 0 : itemsCompleted;
    if (checkpoint != null) {
      _pending = Map<String, Object?>.of(checkpoint);
    }
    await _write(
      SessionStatus.completed,
      checkpoint: _pending,
      itemsCompleted: _itemsCompleted,
    );
  }

  /// Cancels any pending debounce timer.
  ///
  /// Called from the owning controller's `dispose`. The last *checkpointed*
  /// state is already on disk, so no data is lost here.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  // --- internals ----------------------------------------------------------

  Future<void> _flushPending() async {
    if (_disposed) {
      return;
    }
    await _write(
      SessionStatus.active,
      checkpoint: _pending,
      itemsCompleted: _itemsCompleted,
    );
  }

  Future<void> _write(
    SessionStatus status, {
    required Map<String, Object?> checkpoint,
    required int itemsCompleted,
  }) async {
    if (_disposed && status != SessionStatus.completed) {
      return;
    }
    final DateTime now = _clock.now();
    final bool finished = status != SessionStatus.active;
    final LearningSession session = LearningSession(
      id: _sessionId,
      userId: _userId,
      sessionType: _sessionType,
      startedAt: _startedAt,
      endedAt: finished ? now : null,
      durationSec: finished
          ? now.difference(_startedAt).inSeconds
          : null,
      itemsCompleted: itemsCompleted,
      checkpoint: checkpoint,
      status: status,
    );
    try {
      await _progress.saveSession(session);
    } on Object catch (error, stackTrace) {
      // Autosave must never take down a live session.
      appLogger.warning('Session autosave failed.', error, stackTrace);
    }
  }

  /// Whether [start] has been called.
  bool get isStarted => _started;
}
