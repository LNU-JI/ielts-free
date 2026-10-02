/// Mistake repository.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/mistake.dart';
import 'package:ielts_free/core/storage/dao/user/mistake_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';

/// Read/write access to the mistake queue.
abstract interface class MistakeRepository {
  /// A page of mistakes, optionally filtered.
  Future<PagedList<Mistake>> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    RefType? refType,
    ErrorType? errorType,
    bool onlyActive = true,
  });

  /// The mistake with [id], or `null`.
  Future<Mistake?> byId(int id);

  /// Records a wrong answer (insert or bump) and returns the row id.
  Future<int> recordWrong(Mistake mistake);

  /// Sets the mastery of one mistake.
  Future<void> updateMastery(int id, double mastery);

  /// Number of active mistakes.
  Future<int> countActive(String userId);

  /// Active mistakes ordered by review priority.
  Future<List<Mistake>> forReview(String userId, {int limit = 10});

  /// Active mistakes grouped by error type.
  Future<Map<String, int>> countByErrorType(String userId);
}

/// SQLite-backed [MistakeRepository].
class SqliteMistakeRepository implements MistakeRepository {
  SqliteMistakeRepository(this._dao);

  final MistakeDao _dao;

  @override
  Future<PagedList<Mistake>> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    RefType? refType,
    ErrorType? errorType,
    bool onlyActive = true,
  }) =>
      runDbGuarded('MISTAKE_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<Mistake> items = await _dao.page(
          userId,
          limit: pageSize,
          offset: offset,
          refType: refType,
          errorType: errorType,
          onlyActive: onlyActive,
        );
        final int total = await _dao.count(
          userId,
          refType: refType,
          errorType: errorType,
          onlyActive: onlyActive,
        );
        return PagedList<Mistake>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<Mistake?> byId(int id) =>
      runDbGuarded('MISTAKE_BY_ID', () => _dao.byId(id));

  @override
  Future<int> recordWrong(Mistake mistake) =>
      runDbGuarded('MISTAKE_RECORD', () => _dao.recordWrong(mistake));

  @override
  Future<void> updateMastery(int id, double mastery) =>
      runDbGuarded('MISTAKE_MASTERY', () => _dao.updateMastery(id, mastery));

  @override
  Future<int> countActive(String userId) =>
      runDbGuarded('MISTAKE_COUNT', () => _dao.countActive(userId));

  @override
  Future<List<Mistake>> forReview(String userId, {int limit = 10}) =>
      runDbGuarded('MISTAKE_REVIEW', () => _dao.forReview(userId, limit: limit));

  @override
  Future<Map<String, int>> countByErrorType(String userId) =>
      runDbGuarded('MISTAKE_BY_TYPE', () => _dao.countByErrorType(userId));
}
