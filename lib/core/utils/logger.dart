/// Local-only logging.
///
/// ## Privacy red line
///
/// Logs are written to the local developer log stream **only**. Nothing is ever
/// sent over the network, uploaded, or persisted to a remote service
/// (docs/BRIEF.md §88). `print` is banned project-wide (see
/// `analysis_options.yaml`), so this module routes records through
/// `dart:developer`'s [developer.log] instead.
library;

import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// The application-wide logger. Use `appLogger.info(...)` etc.
final Logger appLogger = Logger('ielts_free');

bool _loggingInitialised = false;

/// Installs the root log handler exactly once.
///
/// [level] is the minimum severity that is emitted. [enabled] lets callers mute
/// logging (for example in release builds) without touching call sites.
void initAppLogging({
  Level level = Level.INFO,
  bool enabled = true,
}) {
  if (_loggingInitialised) {
    return;
  }
  _loggingInitialised = true;

  Logger.root.level = level;
  Logger.root.onRecord.listen((LogRecord record) {
    if (!enabled) {
      return;
    }
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      time: record.time,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
