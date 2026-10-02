/// Content-database test — FR-006 / FR-090 / ARCHITECTURE §4.1.
///
/// Verifies the shipped read-only content library: it opens read-only, rejects
/// writes, is internally consistent, carries the expected V0.1 counts and its
/// SHA256 matches the manifest.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabaseFactory);

  // Absolute paths: `sqflite_common_ffi` resolves a *relative* database path
  // against its own working dir (`.dart_tool/sqflite_common_ffi/databases/`),
  // so `assets/seed/...` would never be found. `p.absolute` anchors to the
  // process working directory, which is the project root under `flutter test`.
  final String dbPath = p.absolute('assets/seed/ielts_content_v1.db');
  final String manifestPath = p.absolute('assets/seed/manifest.json');

  // Nullable so a failed `setUpAll` (e.g. the file is missing) does not turn
  // `tearDownAll` into a second, misleading `LateInitializationError`.
  Database? db;

  setUpAll(() async {
    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: true),
    );
  });

  tearDownAll(() async {
    await db?.close();
  });

  test('the content database ships with the app', () {
    expect(File(dbPath).existsSync(), isTrue);
  });

  test('integrity_check passes', () async {
    final List<Map<String, Object?>> rows =
        await db!.rawQuery('PRAGMA integrity_check');
    expect(rows.first.values.first, 'ok');
  });

  test('all expected content tables exist', () async {
    final List<Map<String, Object?>> rows = await db!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final List<String> tables = rows
        .map((Map<String, Object?> r) => r['name']! as String)
        .toList(growable: false);
    expect(
      tables,
      containsAll(<String>[
        'vocabulary',
        'vocabulary_topics',
        'reading_passages',
        'reading_questions',
        'reading_options',
        'content_metadata',
      ]),
    );
  });

  test('row counts match the V0.1 seed spec (300 / 8 / 80)', () async {
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(
          await db!.rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;
    expect(await count('vocabulary'), 300);
    expect(await count('reading_passages'), 8);
    expect(await count('reading_questions'), 80);
  });

  test('reading questions cover TFNG / MC / SUMMARY_COMPLETION', () async {
    final List<Map<String, Object?>> rows = await db!.rawQuery(
      'SELECT DISTINCT question_type FROM reading_questions',
    );
    final List<String> types = rows
        .map((Map<String, Object?> r) => r['question_type']! as String)
        .toList(growable: false);
    expect(types, containsAll(<String>['TFNG', 'MC', 'SUMMARY_COMPLETION']));
  });

  test('the database is read-only (writes throw)', () async {
    await expectLater(
      db!.rawInsert(
        "INSERT INTO vocabulary(word, meaning_cn, difficulty) VALUES('x','y',3)",
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('manifest checksum matches the file SHA256', () {
    final File file = File(dbPath);
    final String actual =
        sha256.convert(file.readAsBytesSync()).toString();
    final Map<String, dynamic> manifest =
        jsonDecode(File(manifestPath).readAsStringSync())
            as Map<String, dynamic>;
    expect(actual, manifest['checksum']);
    expect(manifest['vocabularyCount'], 300);
    expect(manifest['readingCount'], 8);
    expect(manifest['readingQuestionCount'], 80);
  });
}
