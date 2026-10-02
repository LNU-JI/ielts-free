import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/app.dart';
import 'package:ielts_free/core/database/database_factory.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Application entry point.
///
/// Responsibilities:
/// 1. Ensure the Flutter bindings are initialised.
/// 2. Install the local-only logger.
/// 3. Configure the correct SQLite factory for the current platform
///    (Android/iOS: default `sqflite`; Windows/Linux/macOS: `sqflite_common_ffi`).
/// 4. Start the widget tree inside a `ProviderScope`.
///
/// The heavy database work (opening the user database, importing the read-only
/// content database, building indexes) is intentionally NOT done here. It runs
/// inside `BootstrapController` (see `lib/core/providers/bootstrap_provider.dart`)
/// so the UI can show progress and so it can be overridden in tests.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initAppLogging();
  AppDatabaseFactory.init();

  runApp(
    const ProviderScope(
      child: IeltsFreeApp(),
    ),
  );
}
