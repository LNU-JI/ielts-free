/// Read-only content database.
///
/// ## Lifecycle
///
/// 1. On first launch the compiled asset (`assets/seed/ielts_content_v1.db`) is
///    copied into `<documents>/content/ielts_content_v1.db` (the *built-in*
///    copy).
/// 2. The copy is verified against the expected SHA256 (when one is supplied).
/// 3. **V0.2 offline content packs**: when the learner imports a pack from a
///    local file (see `ContentPackService`), it is validated and copied into
///    `<documents>/content/imported/ielts_content_v1.db` together with a
///    `pack.json` marker. [database] then prefers that imported pack and only
///    falls back to the built-in asset copy when it is absent or unreadable.
/// 4. The database is opened with `readOnly: true` so **any write throws**
///    (docs/ARCHITECTURE-v0.1.md §4.1 — hard constraint).
///
/// The built-in copy is *always* the fallback: no import can ever leave the app
/// without a usable content database, because the asset copy is re-materialised
/// from `rootBundle` on demand.
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
import 'package:ielts_free/core/models/content_metadata.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Manages the imported, read-only content database.
class ContentDatabase {
  ContentDatabase({
    this.assetPath = AppConstants.seedContentDbAssetPath,
    this.fileName = AppConstants.contentDbFileName,
    this.directoryName = AppConstants.contentDirName,
    this.importedDirName = defaultImportedDirName,
    this.markerFileName = defaultMarkerFileName,
  });

  /// Sub-directory (under the content directory) holding an imported pack.
  static const String defaultImportedDirName = 'imported';

  /// Marker file (written last) that activates an imported pack.
  static const String defaultMarkerFileName = 'pack.json';

  /// Asset key of the compiled content database shipped with the app.
  final String assetPath;

  /// File name of the imported copy.
  final String fileName;

  /// Sub-directory (under the documents directory) that holds the copy.
  final String directoryName;

  /// Sub-directory that holds an *imported* (V0.2) content pack.
  final String importedDirName;

  /// Marker file name written last, once an imported pack is in place.
  final String markerFileName;

  Database? _db;

  /// The open read-only database (opens on first access).
  Future<Database> get database async => _db ??= await _open();

  /// Whether the built-in copy already exists on disk.
  Future<bool> isImported() async {
    final File file = File(await importedFilePath());
    return file.exists();
  }

  /// Absolute path of the built-in content database copy.
  Future<String> importedFilePath() async {
    final Directory dir = await _contentDirectory();
    return p.join(dir.path, fileName);
  }

  /// Absolute path of the *imported* content pack database.
  Future<String> importedPackFilePath() async {
    final Directory dir = await _importedPackDirectory();
    return p.join(dir.path, fileName);
  }

  /// Absolute path of the marker that activates the imported pack.
  Future<String> importedPackMarkerPath() async {
    final Directory dir = await _importedPackDirectory();
    return p.join(dir.path, markerFileName);
  }

  /// The imported pack directory (created on demand).
  Future<Directory> importedPackDirectory() => _importedPackDirectory();

  /// Whether an imported pack is present and activated by its marker.
  Future<bool> hasImportedPack() async {
    final File marker = File(await importedPackMarkerPath());
    final File pack = File(await importedPackFilePath());
    return await marker.exists() && await pack.exists();
  }

  /// Removes the imported pack (marker first, so resolution falls back to the
  /// built-in copy even if the delete is interrupted).
  Future<void> clearImportedPack() async {
    final File marker = File(await importedPackMarkerPath());
    if (await marker.exists()) {
      await marker.delete();
    }
    final String packPath = await importedPackFilePath();
    for (final String candidate in <String>[packPath, '$packPath.bak']) {
      final File file = File(candidate);
      if (await file.exists()) {
        await file.delete();
      }
    }
    // Drop any stale temp / backup files left by an interrupted import.
    final Directory dir = await _importedPackDirectory();
    await for (final FileSystemEntity entity in dir.list()) {
      final String name = p.basename(entity.path);
      if (entity is File &&
          name.startsWith('pack.') &&
          (name.endsWith('.tmp') || name.endsWith('.bak'))) {
        await entity.delete();
      }
    }
  }

  /// Path of the database that [database] will open: the imported pack when one
  /// is active, otherwise the built-in copy (materialised from the asset).
  Future<String> activePackPath() async {
    if (await hasImportedPack()) {
      return importedPackFilePath();
    }
    return ensureImported();
  }

  /// Reads the active `content_metadata` row from the open content database.
  Future<ContentMetadata?> activeMetadata() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'content_metadata',
      where: 'is_active = ?',
      whereArgs: <Object?>[1],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ContentMetadata.fromMap(rows.first);
  }

  /// Copies the built-in asset into the documents directory when missing or when
  /// the byte length differs from the packaged asset. Returns the target path.
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

  /// Opens the active content database in read-only mode.
  ///
  /// Prefers the imported pack; on **any** failure it logs and falls back to the
  /// built-in asset copy so the app can always reach its content.
  Future<Database> _open() async {
    if (await _hasImportedPackSafely()) {
      try {
        final String importedPath = await importedPackFilePath();
        return await databaseFactory.openDatabase(
          importedPath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: true),
        );
      } on Object catch (error, stackTrace) {
        appLogger.warning(
          'Imported content pack could not be opened; falling back to the '
          'built-in pack.',
          error,
          stackTrace,
        );
      }
    }

    try {
      final String path = await ensureImported();
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: true),
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

  /// [hasImportedPack] that never throws — a marker read failure must degrade to
  /// "no imported pack", never break startup.
  Future<bool> _hasImportedPackSafely() async {
    try {
      return await hasImportedPack();
    } on Object catch (error, stackTrace) {
      appLogger.warning('Imported pack probe failed.', error, stackTrace);
      return false;
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

  /// Verifies the **built-in** copy against [expectedSha256Hex].
  ///
  /// This is the startup integrity check for the asset shipped with the app
  /// (`manifest.json.checksum` is the SHA256 of the compiled `.db` *file*). It
  /// deliberately targets the built-in copy, not the active pack, so an imported
  /// pack can never make the built-in verification fail.
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

  /// Computes the SHA256 of the **built-in** content database copy.
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

  Future<Directory> _importedPackDirectory() async {
    final Directory parent = await _contentDirectory();
    final Directory dir = Directory(p.join(parent.path, importedDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
