/// Domain exceptions and the single mapping point from exceptions to
/// user-visible [Failure]s.
///
/// Layering note: [Failure] lives in `result.dart`; [AppException] lives here.
/// This file imports `result.dart` (never the other way round) so the two files
/// cannot form an import cycle.
library;

import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:ielts_free/core/errors/result.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Base class for all application-level exceptions.
///
/// Data / domain code throws [AppException] (never a bare `Exception`) and the
/// boundary converts it to a [Failure] via [failureFromException].
class AppException implements Exception {
  const AppException(
    this.code,
    this.message, {
    this.cause,
    this.stackTrace,
  });

  /// Stable machine-readable code.
  final String code;

  /// Short, user-facing description.
  final String message;

  /// Original error, for logging only.
  final Object? cause;

  /// Original stack trace, for logging only.
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException($code): $message';
}

/// Failure to open, read or write a local database.
class DatabaseException extends AppException {
  const DatabaseException(
    super.code,
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// The read-only content database is missing or corrupt.
class ContentMissingException extends AppException {
  const ContentMissingException([
    String message = '内容库缺失或损坏，请重新安装应用。',
  ]) : super('CONTENT_MISSING', message);
}

/// A requested record does not exist.
class NotFoundException extends AppException {
  const NotFoundException(
    super.code,
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Input failed validation before it reached the database.
class ValidationException extends AppException {
  const ValidationException(
    super.code,
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// A feature that is intentionally not implemented in V0.1.
class NotImplementedException extends AppException {
  const NotImplementedException([
    String message = '该功能尚未实现。',
  ]) : super('NOT_IMPLEMENTED', message);
}

/// Generic fallback message for unexpected errors.
const String _kGenericErrorMessage = '出现了一些问题，请稍后重试。';

/// Maps any thrown [error] to a [Failure] and writes a local log entry.
///
/// - [AppException] keeps its own code / message.
/// - sqflite errors become `DB_ERROR`.
/// - anything else becomes `UNKNOWN`.
Failure failureFromException(Object error, [StackTrace? stackTrace]) {
  final Failure failure;
  if (error is AppException) {
    failure = Failure(
      code: error.code,
      message: error.message,
      cause: error.cause ?? error,
    );
  } else if (error is sqflite.DatabaseException) {
    failure = Failure(
      code: 'DB_ERROR',
      message: '本地数据访问失败，请重试。',
      cause: error,
    );
  } else {
    failure = Failure(
      code: 'UNKNOWN',
      message: _kGenericErrorMessage,
      cause: error,
    );
  }

  appLogger.warning(
    'Operation failed: ${failure.code} — ${failure.message}',
    error,
    stackTrace,
  );
  return failure;
}

/// Runs an async [action], converting any thrown error into an [Err].
Future<Result<T>> runGuarded<T>(Future<T> Function() action) async {
  try {
    return Ok<T>(await action());
  } on Object catch (error, stackTrace) {
    return Err<T>(failureFromException(error, stackTrace));
  }
}

/// Runs a synchronous [action], converting any thrown error into an [Err].
Result<T> guardSync<T>(T Function() action) {
  try {
    return Ok<T>(action());
  } on Object catch (error, stackTrace) {
    return Err<T>(failureFromException(error, stackTrace));
  }
}

/// Runs a database [action], rethrowing [AppException] unchanged and wrapping
/// any other error in a [DatabaseException] tagged with [code].
///
/// Repositories use this so that every persistence failure surfaces as a typed,
/// user-safe [AppException] instead of a raw sqflite error.
Future<T> runDbGuarded<T>(String code, Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on Object catch (error, stackTrace) {
    throw DatabaseException(
      code,
      '本地数据访问失败，请重试。',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
