/// Functional result type used across the data and domain layers.
///
/// The data layer never throws raw exceptions to callers; it returns a
/// [Result]. Callers branch on [Ok] / [Err] with a `switch` expression
/// (see docs/ARCHITECTURE-v0.1.md §9.2).
///
/// [Ok] and [Err] live in the **same library** as the sealed base so the type is
/// exhaustively switchable without importing extra files (Dart requires sealed
/// subtypes to share the declaring library).
library;

/// A recoverable error that is safe to surface to the UI.
///
/// - [code] is a stable, machine-readable identifier (e.g. `DB_OPEN_FAILED`).
/// - [message] is a short, user-facing description.
/// - [cause] keeps the original error for the local log only; it is never shown
///   to the user.
class Failure {
  const Failure({
    required this.code,
    required this.message,
    this.cause,
  });

  /// Stable machine-readable error code.
  final String code;

  /// Short, user-facing description.
  final String message;

  /// Original error object, for the local log only.
  final Object? cause;

  @override
  String toString() => 'Failure($code): $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Failure &&
        other.code == code &&
        other.message == message &&
        other.cause == cause;
  }

  @override
  int get hashCode => Object.hash(code, message, cause);
}

/// Base type for operations that can fail.
sealed class Result<T> {
  const Result();

  /// Whether this result is an [Ok].
  bool get isOk => this is Ok<T>;

  /// Whether this result is an [Err].
  bool get isErr => this is Err<T>;

  /// The success value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok<T>(:final T value) => value,
        Err<T>() => null,
      };

  /// The [Failure], or `null` when this is an [Ok].
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final Failure failure) => failure,
      };

  /// Folds both branches into a single value of type [R].
  R fold<R>(
    R Function(T value) onOk,
    R Function(Failure failure) onErr,
  ) =>
      switch (this) {
        Ok<T>(:final T value) => onOk(value),
        Err<T>(:final Failure failure) => onErr(failure),
      };
}

/// Successful result carrying [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  /// The success value.
  final T value;
}

/// Failed result carrying a [Failure].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  /// The failure description.
  final Failure failure;
}
