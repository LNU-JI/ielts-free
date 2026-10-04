/// Offline content-pack import / validation service (V0.2).
///
/// ## Why this exists
///
/// Large content (thousands of words, per-word images, …) is hosted on the
/// project's website. The app must **never** fetch it: the release manifest only
/// declares `RECORD_AUDIO`, and `lib/` contains no networking import. Instead the
/// learner downloads the pack in their **browser**, then imports the local file
/// here. The app only ever reads a file from disk, so no `INTERNET` permission is
/// ever needed.
///
/// ## Validation
///
/// A candidate file (`.db` or `.zip`) is imported only when it passes *every*
/// check below; otherwise it is rejected with a clear Chinese reason and the
/// currently-active pack is left untouched:
///
/// 1. the payload is a valid SQLite database (`SQLite format 3\0` header);
/// 2. `PRAGMA integrity_check` reports `ok`;
/// 3. `content_metadata` exists and has **exactly one** `is_active = 1` row;
/// 4. `content_version` parses as `major.minor.patch`;
/// 5. every count column matches the real row count of its content table;
/// 6. the checksum matches the file.
///
/// ### Checksum semantics
///
/// `content_pipeline/build_content_db.py` writes **two different** digests:
/// * `manifest.json.checksum` — the SHA256 of the compiled `.db` **file**;
/// * `content_metadata.checksum` — a deterministic digest over the *content
///   tables* (a row cannot contain the hash of the file that contains it).
///
/// A `.zip` pack bundles `manifest.json`, so the file SHA256 is verified
/// directly. A bare `.db` has no manifest, so the embedded content digest is
/// recomputed with the exact algorithm from `build_content_db.py` and compared.
/// Either way a mismatch is a hard rejection.
///
/// ## Safety
///
/// Import never touches the built-in asset copy or the user database. The new
/// pack is written to a temp file inside the imported directory, then swapped in
/// atomically; the activation marker is written last. Any failure rolls back and
/// leaves the previous pack (or the built-in fallback) intact.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:ielts_free/core/database/content_database.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/content_metadata.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Where the active content database comes from.
enum ContentPackSource {
  /// The read-only asset shipped inside the app.
  builtin,

  /// A pack imported from a local `.db` / `.zip` file.
  imported,
}

/// Snapshot of the active content pack, for the Settings screen.
class ContentPackInfo {
  const ContentPackInfo({
    required this.source,
    this.contentVersion,
    this.vocabularyCount = 0,
    this.readingCount = 0,
    this.listeningCount = 0,
    this.writingCount = 0,
    this.speakingCount = 0,
    this.importedAt,
    this.originalFileName,
  });

  /// Whether the built-in asset or an imported pack is active.
  final ContentPackSource source;

  /// Active `content_version`, when the database could be read.
  final String? contentVersion;

  /// Vocabulary item count.
  final int vocabularyCount;

  /// Reading passage count.
  final int readingCount;

  /// Listening section count.
  final int listeningCount;

  /// Writing task count.
  final int writingCount;

  /// Speaking topic count.
  final int speakingCount;

  /// When the active imported pack was imported (UTC).
  final DateTime? importedAt;

  /// Original file name of the active imported pack.
  final String? originalFileName;

  /// Convenience: an imported pack is active.
  bool get isImported => source == ContentPackSource.imported;
}

/// Outcome of validating a candidate content-pack file.
class ContentPackValidation {
  const ContentPackValidation._({
    required this.ok,
    this.reason,
    this.metadata,
    this.fileSha256,
    this.sourceFileName,
  });

  /// The file is a valid content pack.
  const ContentPackValidation.success(
    ContentMetadata metadata, {
    String? fileSha256,
    String? sourceFileName,
  }) : this._(
          ok: true,
          metadata: metadata,
          fileSha256: fileSha256,
          sourceFileName: sourceFileName,
        );

  /// The file was rejected; [reason] is a user-facing Chinese explanation.
  const ContentPackValidation.failure(String reason)
      : this._(ok: false, reason: reason);

  /// Whether the candidate passed every check.
  final bool ok;

  /// Rejection reason (only set when [ok] is `false`).
  final String? reason;

  /// Metadata read from the candidate (only set when [ok] is `true`).
  final ContentMetadata? metadata;

  /// SHA256 of the candidate `.db` bytes.
  final String? fileSha256;

  /// Original file name of the candidate.
  final String? sourceFileName;
}

/// Validates and imports offline content packs.
class ContentPackService {
  ContentPackService({required ContentDatabase contentDatabase})
      : _contentDatabase = contentDatabase;

  final ContentDatabase _contentDatabase;

  /// Content tables hashed by the deterministic content digest, in the exact
  /// order used by `content_pipeline/build_content_db.py` (`_CONTENT_DIGEST_TABLES`).
  static const List<MapEntry<String, String>> _digestTables =
      <MapEntry<String, String>>[
    MapEntry<String, String>('vocabulary', 'id'),
    MapEntry<String, String>('vocabulary_topics', 'vocabulary_id, topic'),
    MapEntry<String, String>('reading_passages', 'id'),
    MapEntry<String, String>('reading_questions', 'id'),
    MapEntry<String, String>('reading_options', 'id'),
    MapEntry<String, String>('listening_sections', 'id'),
    MapEntry<String, String>('listening_cues', 'id'),
    MapEntry<String, String>('listening_questions', 'id'),
    MapEntry<String, String>('speaking_topics', 'id'),
    MapEntry<String, String>('speaking_questions', 'id'),
    MapEntry<String, String>('writing_tasks', 'id'),
    MapEntry<String, String>('writing_samples', 'id'),
    MapEntry<String, String>('writing_phrases', 'id'),
  ];

  /// SQLite file header magic (`SQLite format 3` + NUL).
  static const List<int> _sqliteMagic = <int>[
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  static final RegExp _semverPattern =
      RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.\-]+)?$');

  /// Describes the currently-active content pack.
  Future<ContentPackInfo> current() async {
    final bool imported = await _contentDatabase.hasImportedPack();
    final ContentMetadata? metadata = await _contentDatabase.activeMetadata();

    String? originalFileName;
    DateTime? importedAt;
    if (imported) {
      final Map<String, Object?>? marker = await _readMarker();
      if (marker != null) {
        originalFileName = asString(marker['originalFileName']);
        importedAt = AppDateUtils.parseUtcIso(asString(marker['importedAt']));
      }
    }

    return ContentPackInfo(
      source: imported ? ContentPackSource.imported : ContentPackSource.builtin,
      contentVersion: metadata?.contentVersion,
      vocabularyCount: metadata?.vocabularyCount ?? 0,
      readingCount: metadata?.readingCount ?? 0,
      listeningCount: metadata?.listeningCount ?? 0,
      writingCount: metadata?.writingCount ?? 0,
      speakingCount: metadata?.speakingCount ?? 0,
      importedAt: importedAt,
      originalFileName: originalFileName,
    );
  }

  /// Validates [sourcePath] without touching the active pack.
  Future<ContentPackValidation> validate(String sourcePath) async {
    try {
      final _PreparedPack prepared = await _prepare(sourcePath);
      return ContentPackValidation.success(
        prepared.metadata,
        fileSha256: prepared.fileSha256,
        sourceFileName: prepared.originalFileName,
      );
    } on AppException catch (error) {
      return ContentPackValidation.failure(error.message);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Content pack validation failed.', error, stackTrace);
      return const ContentPackValidation.failure(
        '内容包校验失败，请确认文件是有效的内容包。',
      );
    }
  }

  /// Validates [sourcePath] and, when valid, installs it as the active pack.
  ///
  /// Throws an [AppException] when the file is invalid or the install fails; in
  /// that case the previously-active pack (or the built-in fallback) is intact.
  Future<ContentPackInfo> importFromPath(String sourcePath) async {
    final _PreparedPack prepared = await _prepare(sourcePath);

    final Directory dir = await _contentDatabase.importedPackDirectory();
    final String targetPath = await _contentDatabase.importedPackFilePath();
    final File target = File(targetPath);
    final File backup = File('$targetPath.bak');
    final File dbTemp = File(p.join(dir.path, 'pack.db.tmp'));
    final File markerTemp = File(p.join(dir.path, 'pack.json.tmp'));
    final File marker =
        File(await _contentDatabase.importedPackMarkerPath());
    final File markerBackup = File('${marker.path}.bak');

    try {
      await dbTemp.writeAsBytes(prepared.dbBytes, flush: true);
      await markerTemp.writeAsString(
        _markerJson(prepared, sourcePath),
        flush: true,
      );

      // The live connection must be closed before the file is swapped.
      await _contentDatabase.close();

      // Move the previous pack (if any) aside so the swap is atomic and can be
      // rolled back. `File.rename` refuses an existing destination on Windows,
      // so both the db and the marker must be cleared first.
      await _deleteQuietly(backup);
      await _deleteQuietly(markerBackup);
      final bool hadTarget = await target.exists();
      if (hadTarget) {
        await target.rename(backup.path);
      }
      final bool hadMarker = await marker.exists();
      if (hadMarker) {
        await marker.rename(markerBackup.path);
      }

      try {
        await dbTemp.rename(targetPath);
        await markerTemp.rename(marker.path);
      } on Object {
        // Roll back so nothing is half-installed.
        await _deleteQuietly(marker);
        await _deleteQuietly(target);
        if (hadTarget && await backup.exists()) {
          await backup.rename(targetPath);
        }
        if (hadMarker && await markerBackup.exists()) {
          await markerBackup.rename(marker.path);
        }
        rethrow;
      }

      await _deleteQuietly(backup);
      await _deleteQuietly(markerBackup);
      appLogger.info(
        'Imported content pack v${prepared.metadata.contentVersion} '
        'from ${p.basename(sourcePath)}.',
      );
      // `await` is required: without it the returned Future would escape the
      // try/catch, so a failure while reading the freshly-installed pack would
      // bypass the logging + DatabaseException wrapping below and leak a raw
      // error instead of the user-facing Chinese message.
      return await current();
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      await _deleteQuietly(dbTemp);
      await _deleteQuietly(markerTemp);
      appLogger.severe('Content pack import failed.', error, stackTrace);
      throw DatabaseException(
        'CONTENT_PACK_IMPORT_FAILED',
        '内容包导入失败，请重试。',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Removes any imported pack and falls back to the built-in content.
  Future<void> restoreBuiltinPack() async {
    await _contentDatabase.close();
    await _contentDatabase.clearImportedPack();
    await _contentDatabase.ensureImported();
    appLogger.info('Restored built-in content pack.');
  }

  // --- internals ----------------------------------------------------------

  Future<_PreparedPack> _prepare(String sourcePath) async {
    final File file = File(sourcePath);
    if (!await file.exists()) {
      throw const ValidationException('CONTENT_PACK_MISSING', '找不到所选文件，请重新选择。');
    }
    final Uint8List raw = await file.readAsBytes();
    if (raw.isEmpty) {
      throw const ValidationException('CONTENT_PACK_EMPTY', '所选文件为空，无法导入。');
    }

    final _PackPayload payload = _extractPayload(raw, p.basename(sourcePath));
    if (!_hasSqliteHeader(payload.dbBytes)) {
      throw const ValidationException(
        'CONTENT_PACK_NOT_SQLITE',
        '所选文件不是有效的 SQLite 内容库。',
      );
    }

    final String fileSha256 = sha256.convert(payload.dbBytes).toString();

    final Directory tempDir = await Directory.systemTemp.createTemp('ielts_pack_');
    final File probe = File(p.join(tempDir.path, 'candidate.db'));
    try {
      await probe.writeAsBytes(payload.dbBytes, flush: true);
      final ContentMetadata metadata =
          await _validateDatabase(probe.path, payload, fileSha256);
      return _PreparedPack(
        dbBytes: payload.dbBytes,
        metadata: metadata,
        fileSha256: fileSha256,
        originalFileName: payload.originalFileName,
      );
    } finally {
      await _deleteQuietly(tempDir);
    }
  }

  Future<ContentMetadata> _validateDatabase(
    String path,
    _PackPayload payload,
    String fileSha256,
  ) async {
    final Database db;
    try {
      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
    } on Object catch (error, stackTrace) {
      throw ValidationException(
        'CONTENT_PACK_OPEN_FAILED',
        '内容包无法打开，可能不是有效的 SQLite 文件。',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await _checkIntegrity(db);
      await _checkMetadataTable(db);
      final ContentMetadata metadata = await _readActiveMetadata(db);
      _checkVersion(metadata);
      await _checkCounts(db, metadata);
      await _checkChecksum(db, payload, metadata, fileSha256);
      return metadata;
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw ValidationException(
        'CONTENT_PACK_UNREADABLE',
        '内容包无法读取，可能已损坏。',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      await db.close();
    }
  }

  Future<void> _checkIntegrity(Database db) async {
    final List<Map<String, Object?>> rows =
        await db.rawQuery('PRAGMA integrity_check');
    final String result =
        rows.isEmpty ? '' : '${rows.first.values.first ?? ''}';
    if (result.toLowerCase() != 'ok') {
      throw ValidationException(
        'CONTENT_PACK_INTEGRITY',
        '内容库完整性校验未通过（integrity_check 返回「$result」）。',
      );
    }
  }

  Future<void> _checkMetadataTable(Database db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'content_metadata'",
    );
    if (rows.isEmpty) {
      throw const ValidationException(
        'CONTENT_PACK_NO_METADATA',
        '内容包缺少 content_metadata 表，不是合法的内容库。',
      );
    }
  }

  Future<ContentMetadata> _readActiveMetadata(Database db) async {
    final List<Map<String, Object?>> rows = await db.query(
      'content_metadata',
      where: 'is_active = ?',
      whereArgs: <Object?>[1],
    );
    if (rows.length != 1) {
      throw ValidationException(
        'CONTENT_PACK_ACTIVE_ROWS',
        'content_metadata 必须恰好有一行 is_active=1（当前 ${rows.length} 行）。',
      );
    }
    return ContentMetadata.fromMap(rows.first);
  }

  void _checkVersion(ContentMetadata metadata) {
    if (!_semverPattern.hasMatch(metadata.contentVersion)) {
      throw ValidationException(
        'CONTENT_PACK_VERSION',
        '内容版本号无法解析：「${metadata.contentVersion}」。',
      );
    }
  }

  Future<void> _checkCounts(Database db, ContentMetadata metadata) async {
    final List<String> mismatches = <String>[];
    await _compareCount(db, 'vocabulary', metadata.vocabularyCount, '词汇', mismatches);
    await _compareCount(
        db, 'reading_passages', metadata.readingCount, '阅读', mismatches);
    await _compareCount(
        db, 'listening_sections', metadata.listeningCount, '听力', mismatches);
    await _compareCount(
        db, 'writing_tasks', metadata.writingCount, '写作', mismatches);
    await _compareCount(
        db, 'speaking_topics', metadata.speakingCount, '口语', mismatches);
    if (mismatches.isNotEmpty) {
      throw ValidationException(
        'CONTENT_PACK_COUNT_MISMATCH',
        '内容数量与元数据不一致：${mismatches.join('；')}。',
      );
    }
  }

  Future<void> _compareCount(
    Database db,
    String table,
    int expected,
    String label,
    List<String> mismatches,
  ) async {
    final int actual;
    try {
      actual = await _countRows(db, table);
    } on Object {
      mismatches.add('缺少 $table 表');
      return;
    }
    if (actual != expected) {
      mismatches.add('$label $table 应为 $expected，实际 $actual');
    }
  }

  Future<int> _countRows(Database db, String table) async {
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    if (rows.isEmpty) {
      return 0;
    }
    final Object? value = rows.first['c'];
    return value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
  }

  Future<void> _checkChecksum(
    Database db,
    _PackPayload payload,
    ContentMetadata metadata,
    String fileSha256,
  ) async {
    final String? manifest = payload.manifestChecksum;
    final String? expected =
        (manifest != null && manifest.isNotEmpty) ? manifest : metadata.checksum;
    if (expected == null || expected.isEmpty) {
      throw const ValidationException(
        'CONTENT_PACK_NO_CHECKSUM',
        '内容包缺少校验和，无法验证完整性。',
      );
    }
    // 1. Fast path: the expected value is the SHA256 of the .db file itself
    //    (this is what `manifest.json.checksum` holds).
    if (expected.toLowerCase() == fileSha256.toLowerCase()) {
      return;
    }
    // 2. Fallback: the expected value is the embedded content digest
    //    (`content_metadata.checksum`), recomputed exactly as the pipeline does.
    final String contentDigest = await _computeContentDigest(db);
    if (expected.toLowerCase() == contentDigest.toLowerCase()) {
      return;
    }
    throw const ValidationException(
      'CONTENT_PACK_CHECKSUM',
      '内容包校验和不一致，文件可能已损坏或被篡改。',
    );
  }

  /// Deterministic SHA256 over the logical content tables — a byte-for-byte
  /// reimplementation of `compute_content_digest()` in `build_content_db.py`.
  Future<String> _computeContentDigest(Database db) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    for (final MapEntry<String, String> table in _digestTables) {
      final List<Map<String, Object?>> rows =
          await db.rawQuery('SELECT * FROM ${table.key} ORDER BY ${table.value}');
      for (final Map<String, Object?> row in rows) {
        builder.add(utf8.encode(table.key));
        for (final Object? value in row.values) {
          builder.addByte(0x1f);
          builder.add(utf8.encode(_digestValue(value)));
        }
        builder.addByte(0x1e);
      }
    }
    return sha256.convert(builder.takeBytes()).toString();
  }

  String _digestValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  _PackPayload _extractPayload(Uint8List raw, String fileName) {
    if (_looksLikeZip(raw)) {
      return _extractFromZip(raw, fileName);
    }
    return _PackPayload(
      dbBytes: raw,
      manifestChecksum: null,
      originalFileName: fileName,
    );
  }

  _PackPayload _extractFromZip(Uint8List raw, String fileName) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(raw);
    } on Object catch (error, stackTrace) {
      throw ValidationException(
        'CONTENT_PACK_ZIP_CORRUPT',
        '内容包压缩文件已损坏，无法解压。',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    Uint8List? dbBytes;
    String? manifestChecksum;
    for (final ArchiveFile entry in archive.files) {
      if (!entry.isFile) {
        continue;
      }
      final String baseName = p.basename(entry.name).toLowerCase();
      if (baseName == 'manifest.json') {
        final Uint8List? data = entry.readBytes();
        if (data != null) {
          manifestChecksum = _readManifestChecksum(data);
        }
      } else if (dbBytes == null && baseName.endsWith('.db')) {
        dbBytes = entry.readBytes();
      }
    }

    if (dbBytes == null) {
      throw const ValidationException(
        'CONTENT_PACK_ZIP_NO_DB',
        '压缩包内没有找到 .db 内容库文件。',
      );
    }
    return _PackPayload(
      dbBytes: dbBytes,
      manifestChecksum: manifestChecksum,
      originalFileName: fileName,
    );
  }

  String? _readManifestChecksum(Uint8List data) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, Object?>) {
        return asString(decoded['checksum']);
      }
    } on Object {
      return null;
    }
    return null;
  }

  bool _looksLikeZip(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);

  bool _hasSqliteHeader(Uint8List bytes) {
    if (bytes.length < _sqliteMagic.length) {
      return false;
    }
    for (int i = 0; i < _sqliteMagic.length; i++) {
      if (bytes[i] != _sqliteMagic[i]) {
        return false;
      }
    }
    return true;
  }

  String _markerJson(_PreparedPack prepared, String sourcePath) {
    final Map<String, Object?> payload = <String, Object?>{
      'format': 'ielts-free-content-pack',
      'contentVersion': prepared.metadata.contentVersion,
      'vocabularyCount': prepared.metadata.vocabularyCount,
      'readingCount': prepared.metadata.readingCount,
      'listeningCount': prepared.metadata.listeningCount,
      'writingCount': prepared.metadata.writingCount,
      'speakingCount': prepared.metadata.speakingCount,
      'fileSha256': prepared.fileSha256,
      'originalFileName': p.basename(sourcePath),
      'importedAt': AppDateUtils.nowUtcIso(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<Map<String, Object?>?> _readMarker() async {
    try {
      final File marker = File(await _contentDatabase.importedPackMarkerPath());
      if (!await marker.exists()) {
        return null;
      }
      final Object? decoded = jsonDecode(await marker.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object catch (error, stackTrace) {
      appLogger.warning('Content pack marker unreadable.', error, stackTrace);
      return null;
    }
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete();
      }
    } on Object {
      // Best-effort cleanup; never let a failed delete mask the real error.
    }
  }
}

/// Raw payload extracted from a candidate file.
class _PackPayload {
  const _PackPayload({
    required this.dbBytes,
    required this.manifestChecksum,
    required this.originalFileName,
  });

  final Uint8List dbBytes;
  final String? manifestChecksum;
  final String originalFileName;
}

/// A validated pack, ready to be installed.
class _PreparedPack {
  const _PreparedPack({
    required this.dbBytes,
    required this.metadata,
    required this.fileSha256,
    required this.originalFileName,
  });

  final Uint8List dbBytes;
  final ContentMetadata metadata;
  final String fileSha256;
  final String originalFileName;
}
