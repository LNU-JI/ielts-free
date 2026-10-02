/// Read-only content database.
///
/// ## Lifecycle
///
/// 1. On first launch the compiled asset (`assets/seed/ielts_content_v1.db`) is
///    copied into `<documents>/content/ielts_content_v1.db`.
/// 2. The copy is verified against the expected SHA256 (when one is supplied).
/// 3. The database is opened with `readOnly: true` so **any write throws**
///    (docs/ARCHITECTURE-v0.1.md §4.1 — hard constraint).
///
/// The content database is never written to by the app; it is replaced wholesale
/// when a new content version ships (content and app versions are decoupled).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Manages the imported, read-only content database.
class ContentDatabase {
  ContentDatabase({
    this.assetPath = AppConstants.seedContentDbAssetPath,
    this.fileName = AppConstants.contentDbFileName,
    this.directoryName = AppConstants.contentDirName,
  });

  /// Asset key of the compiled content database shipped with the app.
  final String assetPath;

  /// File name of the imported copy.
  final String fileName;

  /// Sub-directory (under the documents directory) that holds the copy.
  final String directoryName;

  Database? _db;

  /// The open read-only database (opens on first access).
  Future<Database> get database async => _db ??= await _open();

  /// Whether the imported copy already exists on disk.
  Future<bool> isImported() async {
    final File file = File(await importedFilePath());
    return file.exists();
  }

  /// Absolute path of the imported content database.
  Future<String> importedFilePath() async {
    final Directory dir = await _contentDirectory();
    return p.join(dir.path, fileName);
  }

  /// Copies the asset into the documents directory when missing or when the
  /// byte length differs from the packaged asset. Returns the target path.
  Future<String> ensureImported() async {
    final Directory dir = await _contentDirectory();
    final File target = File(p.join(dir.path, fileName));

    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    final bool needsCopy =
        !await target.exists() || await target.length() != bytes.length;
    if (needsCopy) {
      await target.writeAsBytes(bytes, flush: true);
      appLogger.info('Imported content database (${bytes.length} bytes).');
    }
    return target.path;
  }

  /// Opens the imported content database in read-only mode.
  Future<Database> _open() async {
    try {
      final String path = await ensureImported();
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          readOnly: true,
          singleInstance: true,
        ),
      );
    } on Object catch (error, stackTrace) {
      throw DatabaseException(
        'CONTENT_OPEN_FAILED',
        '内容库加载失败，请重新安装应用。',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Reads the SQLite `user_version` of the content database.
  Future<int> contentDbVersion() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('PRAGMA user_version');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Reads `content_metadata.content_version` of the active content package.
  Future<String?> contentMetadataVersion() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'content_metadata',
      columns: <String>['content_version'],
      where: 'is_active = ?',
      whereArgs: <Object?>[1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['content_version'] as String?;
  }

  /// Verifies the imported file against [expectedSha256Hex].
  ///
  /// Returns `true` when the digest matches; throws [ContentMissingException]
  /// on a mismatch so the caller can decide how to recover.
  Future<bool> verifyChecksum(String expectedSha256Hex) async {
    final String path = await ensureImported();
    final Uint8List bytes = await File(path).readAsBytes();
    final String actual = sha256.convert(bytes).toString();
    if (actual.toLowerCase() != expectedSha256Hex.toLowerCase()) {
      throw const ContentMissingException(
        '内容库校验失败（SHA256 不匹配），请重新安装应用。',
      );
    }
    return true;
  }

  /// Computes the SHA256 of the imported content database.
  Future<String> computeChecksum() async {
    final String path = await ensureImported();
    final Uint8List bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Closes the connection (safe to call multiple times).
  Future<void> close() async {
    final Database? db = _db;
    _db = null;
    await db?.close();
  }

  Future<Directory> _contentDirectory() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(documents.path, directoryName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
