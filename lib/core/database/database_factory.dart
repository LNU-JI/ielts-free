/// Platform-aware SQLite factory initialisation.
///
/// - **Android / iOS**: the default `sqflite` factory is already registered, so
///   nothing has to be done.
/// - **Windows / Linux / macOS**: `sqflite_common_ffi` is initialised and its
///   `databaseFactoryFfi` is installed globally.
/// - **Web**: unsupported in V0.1 (no-op).
///
/// Call [AppDatabaseFactory.init] once, before any database is opened
/// (`main.dart` does this at startup).
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Installs the correct SQLite implementation for the running platform.
abstract final class AppDatabaseFactory {
  const AppDatabaseFactory._();

  static bool _initialised = false;

  /// Whether [init] has already run.
  static bool get isInitialised => _initialised;

  /// Selects and installs the platform SQLite factory. Idempotent.
  static void init() {
    if (_initialised) {
      return;
    }
    _initialised = true;

    if (kIsWeb) {
      return;
    }

    final bool isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Overrides the global factory, e.g. tests install `databaseFactoryFfi`
  /// together with `databaseFactoryFfiNoIsolate` or an in-memory setup.
  static void overrideFactory(DatabaseFactory factory) {
    _initialised = true;
    databaseFactory = factory;
  }
}
