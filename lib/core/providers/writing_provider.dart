/// Writing providers.
///
/// Wires the writing DAOs to [WritingRepository] and exposes it to the writing
/// controllers. The content DAO reads the read-only content database while the
/// attempt / phrase-book DAOs write the user database, so the repository needs
/// both handles (docs/ARCHITECTURE-v0.1.md §1.1).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/storage/dao/content/writing_dao.dart';
import 'package:ielts_free/core/storage/dao/user/phrase_book_dao.dart';
import 'package:ielts_free/core/storage/dao/user/writing_attempt_dao.dart';
import 'package:ielts_free/core/storage/repositories/writing_repository.dart';

/// Writing content + progress repository.
final FutureProvider<WritingRepository> writingRepositoryProvider =
    FutureProvider<WritingRepository>((Ref ref) async {
  final Database contentDb = await ref.watch(contentDbProvider.future);
  final Database userDb = await ref.watch(userDbProvider.future);
  return SqliteWritingRepository(
    content: WritingDao(contentDb),
    attempts: WritingAttemptDao(userDb),
    phrases: PhraseBookDao(userDb),
  );
});
