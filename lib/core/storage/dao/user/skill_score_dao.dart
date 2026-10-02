/// DAO for `skill_scores`.
library;


import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/skill_score.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes the five-dimension ability scores.
class SkillScoreDao extends BaseDao {
  SkillScoreDao(super.db);

  static const String _table = 'skill_scores';

  /// All scores for [userId].
  Future<List<SkillScore>> forUser(String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
    );
    return rows.map(SkillScore.fromMap).toList(growable: false);
  }

  /// The score for one skill, or `null`.
  Future<SkillScore?> bySkill(String userId, SkillType skill) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND skill = ?',
      whereArgs: <Object?>[userId, skill.wire],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SkillScore.fromMap(rows.first);
  }

  /// Inserts [score] or updates the existing row for `(user, skill)`.
  Future<void> upsert(SkillScore score) async {
    final SkillScore? existing = await bySkill(score.userId ?? '', score.skill);
    if (existing?.id != null) {
      await db.update(
        _table,
        score.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[existing!.id],
      );
      return;
    }
    final Map<String, Object?> map = score.toMap()..remove('id');
    await db.insert(_table, map);
  }

  /// A `skill → score` map for [userId].
  Future<Map<SkillType, double>> scoreMap(String userId) async {
    final List<SkillScore> scores = await forUser(userId);
    return <SkillType, double>{
      for (final SkillScore score in scores) score.skill: score.score,
    };
  }
}
