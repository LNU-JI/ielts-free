/// Application-wide constants for IELTS Free.
///
/// Everything that is a "magic value" shared across layers lives here:
/// database file names, the default local user, asset paths, paging sizes and
/// the app version string.
///
/// Conventions (see docs/ARCHITECTURE-v0.1.md §9):
/// - Storage timestamps are always UTC ISO-8601 strings.
/// - "Day boundaries" (streak, daily statistics, plan dates) use the LOCAL date
///   string `YYYY-MM-DD`.
library;

/// User database schema version.
///
/// Bumped whenever the user-database DDL changes. Migration steps are defined in
/// `lib/core/database/migrations.dart` (T02). Never drop user data on upgrade.
const int kUserDbVersion = 1;

/// Content database schema version (read-only, shipped with the app).
const int kContentDbVersion = 1;

/// Central, immutable collection of app constants.
abstract final class AppConstants {
  // --- Identity -----------------------------------------------------------

  static const String appName = 'IELTS Free';
  static const String appTagline = 'Free Offline IELTS Learning App';
  static const String appVersion = '0.1.0';
  static const String appBuildNumber = '1';

  // --- Databases ----------------------------------------------------------

  /// Read-only content database shipped as an asset.
  static const String contentDbFileName = 'ielts_content_v1.db';

  /// Read-write user database (profile, progress, mistakes, stats, plan).
  static const String userDbFileName = 'ielts_user_v1.db';

  /// Sub-directory (under the app documents directory) that holds the imported
  /// content database.
  static const String contentDirName = 'content';

  /// Sub-directory that holds pre-upgrade database backups.
  static const String backupsDirName = 'backups';

  // --- Default (guest) user ----------------------------------------------

  static const String localUserId = 'local_user';
  static const String localUserDisplayName = 'Local User';
  static const double defaultTargetBand = 7.0;

  /// `null` means "exam date not decided yet".
  static const String? defaultExamDate = null;
  static const int defaultDailyStudyMinutes = 60;

  // --- Assets -------------------------------------------------------------

  static const String seedContentDbAssetPath =
      'assets/seed/ielts_content_v1.db';
  static const String seedManifestAssetPath = 'assets/seed/manifest.json';
  static const String vocabularySeedAssetPath =
      'assets/seed/vocabulary_seed.json';
  static const String readingSeedAssetPath = 'assets/seed/reading_seed.json';
  static const String appLogoAssetPath = 'assets/images/app_logo.png';
  static const String emptyStateAssetPath = 'assets/images/empty_state.png';

  // --- Paging / limits ----------------------------------------------------

  /// Default page size for paginated lists (vocabulary, mistakes, reading).
  static const int defaultPageSize = 20;

  /// Size of the recent-answers window used by the adaptive engine.
  static const int skillScoreWindow = 20;

  /// Number of questions in the onboarding initial ability test (3 × 5 skills).
  static const int initialTestQuestionCount = 15;

  // --- Backup -------------------------------------------------------------

  static const String backupFileName = 'IELTS-Free-Backup.json';

  // --- Layout -------------------------------------------------------------

  /// Width (in logical pixels) at or above which the desktop shell is used.
  static const double desktopBreakpoint = 900.0;
}
