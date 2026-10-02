/// Injectable clock.
///
/// ## Why
///
/// Every adaptive algorithm is a *pure function of an injected clock*
/// (docs/ARCHITECTURE-v0.1.md §5, §9.6). Calling `DateTime.now()` directly would
/// make the algorithms untestable and non-deterministic, so time is obtained
/// **only** through a [Clock]. Production code injects [SystemClock]; unit tests
/// inject [FixedClock] to reproduce any scenario deterministically.
///
/// `SystemClock` is the single, sanctioned place where `DateTime.now()` may be
/// called (see ARCHITECTURE §9.6).
library;

/// A source of the current instant.
abstract interface class Clock {
  /// The current instant, in UTC.
  ///
  /// Implementations must return a UTC [DateTime] so that all persisted
  /// timestamps follow the storage convention of ARCHITECTURE §9.6.
  DateTime now();
}

/// The real clock, backed by `DateTime.now()`.
///
/// This is the **only** place in `lib/core/services/` allowed to read the system
/// clock directly.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A clock that returns a fixed, manually controlled instant.
///
/// Used by unit tests (and by deterministic demos) to reproduce time-dependent
/// behaviour. The instant can be moved with [setNow] / [advance].
class FixedClock implements Clock {
  /// Creates a fixed clock at [instant] (converted to UTC).
  FixedClock(DateTime instant) : _now = instant.toUtc();

  DateTime _now;

  /// The instant currently returned by [now].
  DateTime get instant => _now;

  /// Replaces the current instant.
  void setNow(DateTime instant) {
    _now = instant.toUtc();
  }

  /// Moves the current instant forward (or backward, for negative values).
  void advance(Duration delta) {
    _now = _now.add(delta);
  }

  @override
  DateTime now() => _now;
}
