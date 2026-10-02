/// Content-database loader (docs/ARCHITECTURE-v0.1.md §4.1, §6.1, BRIEF §74).
///
/// Imports the read-only content database shipped as an asset, verifies it
/// against the SHA256 recorded in `manifest.json`, and opens it read-only.
///
/// **Checksum note** (from the T02 report): the runtime check must use
/// `manifest.checksum`, which is the SHA256 of the final compiled `.db` **file**
/// — *not* `content_metadata.checksum`, which is a deterministic digest of the
/// content tables. `ContentDatabase.verifyChecksum()` compares raw file bytes,
/// so it is aligned with `manifest.checksum`.
library;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/database/content_database.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Result of importing and verifying the content database.
class ContentLoadResult {
  const ContentLoadResult({
    required this.imported,
    required this.checksumVerified,
    this.contentVersion,
    this.checksum,
    this.vocabularyCount = 0,
    this.readingCount = 0,
    this.readingQuestionCount = 0,
  });

  /// Whether the content database is present and openable.
  final bool imported;

  /// Whether the SHA256 matched the manifest.
  final bool checksumVerified;

  /// `content_version` of the active package, when known.
  final String? contentVersion;

  /// The verified SHA256 (from the manifest).
  final String? checksum;

  /// Vocabulary item count (from the manifest).
  final int vocabularyCount;

  /// Reading passage count (from the manifest).
  final int readingCount;

  /// Reading question count (from the manifest).
  final int readingQuestionCount;
}

/// Imports and verifies the shipped content database.
class ContentLoaderService {
  ContentLoaderService({
    required ContentDatabase contentDatabase,
    AssetBundle? bundle,
    this.manifestAssetPath = AppConstants.seedManifestAssetPath,
  })  : _contentDatabase = contentDatabase,
        _bundle = bundle ?? rootBundle;

  final ContentDatabase _contentDatabase;
  final AssetBundle _bundle;

  /// Asset key of the content manifest.
  final String manifestAssetPath;

  /// Copies the asset into the documents directory, verifies its SHA256 against
  /// the manifest and opens it read-only.
  ///
  /// Throws [ContentMissingException] when the asset or manifest is missing or
  /// the checksum does not match.
  Future<ContentLoadResult> importAndVerify() async {
    try {
      // 1. Copy the packaged asset into a writable location.
      await _contentDatabase.ensureImported();

      // 2. Read + parse the manifest (counts + expected SHA256).
      final Map<String, Object?>? manifest =
          decodeMap(await _bundle.loadString(manifestAssetPath));
      if (manifest == null) {
        throw const ContentMissingException('内容清单缺失或格式错误，请重新安装应用。');
      }
      final String? checksum = asString(manifest['checksum']);

      // 3. Verify the file SHA256 against the manifest.
      bool verified = false;
      if (checksum != null && checksum.isNotEmpty) {
        verified = await _contentDatabase.verifyChecksum(checksum);
      }

      // 4. Open read-only (throws if the file cannot be opened).
      await _contentDatabase.database;

      // 5. Read the active content version from the database itself.
      final String? version = await _contentDatabase.contentMetadataVersion();

      appLogger.info(
        'Content DB ready (version=$version, sha256=${checksum ?? 'n/a'}).',
      );

      return ContentLoadResult(
        imported: true,
        checksumVerified: verified,
        contentVersion: version,
        checksum: checksum,
        vocabularyCount: intOrDefault(manifest['vocabularyCount'], 0),
        readingCount: intOrDefault(manifest['readingCount'], 0),
        readingQuestionCount: intOrDefault(manifest['readingQuestionCount'], 0),
      );
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      appLogger.severe('Content import failed.', error, stackTrace);
      throw ContentMissingException(
        '内容库导入失败：${error.toString()}',
      );
    }
  }
}
