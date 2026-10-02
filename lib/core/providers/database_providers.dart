/// Database providers.
///
/// Exposes the two database handles (read-only content, read-write user) to the
/// application layer. Opening is async, so the handles are exposed through
/// [FutureProvider]s that can be awaited / overridden in tests.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/database/app_database.dart';
import 'package:ielts_free/core/database/content_database.dart';

/// The user-database manager (owns the file + connection lifecycle).
final Provider<AppDatabase> appDatabaseProvider =
    Provider<AppDatabase>((Ref ref) => AppDatabase());

/// The content-database manager (imports the asset, opens read-only).
final Provider<ContentDatabase> contentDatabaseProvider =
    Provider<ContentDatabase>((Ref ref) => ContentDatabase());

/// The open read-write user database.
final FutureProvider<Database> userDbProvider = FutureProvider<Database>(
  (Ref ref) async => ref.watch(appDatabaseProvider).database,
);

/// The open read-only content database.
final FutureProvider<Database> contentDbProvider = FutureProvider<Database>(
  (Ref ref) async => ref.watch(contentDatabaseProvider).database,
);
