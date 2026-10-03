/// Listening providers.
///
/// Wires the listening content DAO ([ListeningDao], read-only content database)
/// and the user DAOs ([ListeningErrorDao] for the error log, [SentenceBookDao]
/// for bookmarked sentences) to the [ListeningRepository] interface. Only the
/// repository is meant to be read by controllers — never the DAOs directly
/// (docs/ARCHITECTURE-v0.1.md §1.1).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/storage/dao/content/listening_dao.dart';
import 'package:ielts_free/core/storage/dao/user/listening_error_dao.dart';
import 'package:ielts_free/core/storage/dao/user/sentence_book_dao.dart';
import 'package:ielts_free/core/storage/repositories/listening_repository.dart';

/// Read-only listening content DAO (sections / cues / questions).
final FutureProvider<ListeningDao> listeningDaoProvider =
    FutureProvider<ListeningDao>((Ref ref) async {
  final Database db = await ref.watch(contentDbProvider.future);
  return ListeningDao(db);
});

/// User error-log DAO (`listening_error_log`).
final FutureProvider<ListeningErrorDao> listeningErrorDaoProvider =
    FutureProvider<ListeningErrorDao>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return ListeningErrorDao(db);
});

/// User sentence-book DAO (`sentence_book`).
final FutureProvider<SentenceBookDao> sentenceBookDaoProvider =
    FutureProvider<SentenceBookDao>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SentenceBookDao(db);
});

/// Listening repository — the single data entry point for the listening module.
final FutureProvider<ListeningRepository> listeningRepositoryProvider =
    FutureProvider<ListeningRepository>((Ref ref) async {
  return SqliteListeningRepository(
    content: await ref.watch(listeningDaoProvider.future),
    errors: await ref.watch(listeningErrorDaoProvider.future),
    sentences: await ref.watch(sentenceBookDaoProvider.future),
  );
});
