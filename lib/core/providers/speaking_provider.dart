/// Speaking repository provider.
///
/// Wires the read-only content DAO and the writable attempt DAO into the single
/// [SpeakingRepository] the speaking controllers depend on — never the DAOs
/// directly (docs/ARCHITECTURE-v0.1.md §1.1). This mirrors the other
/// repository providers in this folder.
///
/// The speaking **controllers** (`SpeakingListController` /
/// `SpeakingSessionController`) and the recorder / playback abstractions are
/// declared inside `lib/features/speaking/application/` — the same place the
/// reading module keeps its controller providers — so this folder never has to
/// import the feature layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/storage/dao/content/speaking_dao.dart';
import 'package:ielts_free/core/storage/dao/user/speaking_attempt_dao.dart';
import 'package:ielts_free/core/storage/repositories/speaking_repository.dart';

/// Read access to speaking content, read/write access to speaking progress.
final FutureProvider<SpeakingRepository> speakingRepositoryProvider =
    FutureProvider<SpeakingRepository>((Ref ref) async {
  final Database content = await ref.watch(contentDbProvider.future);
  final Database user = await ref.watch(userDbProvider.future);
  return SqliteSpeakingRepository(
    content: SpeakingDao(content),
    attempts: SpeakingAttemptDao(user),
  );
});
