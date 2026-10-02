/// User-profile repository.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/user.dart';
import 'package:ielts_free/core/models/user_profile.dart';
import 'package:ielts_free/core/storage/dao/user/user_dao.dart';
import 'package:ielts_free/core/storage/dao/user/user_profile_dao.dart';

/// Read/write access to the user profile and user row.
abstract interface class UserProfileRepository {
  /// The profile for [userId], or `null`.
  Future<UserProfile?> get(String userId);

  /// Inserts or updates [profile] (also ensuring the `users` row exists).
  Future<void> save(UserProfile profile);

  /// Whether Onboarding has been completed for [userId].
  Future<bool> isOnboardingCompleted(String userId);

  /// Sets the Onboarding flag for [userId].
  Future<void> setOnboardingCompleted(String userId, bool completed);

  /// Returns the existing profile, creating the default guest profile when
  /// none exists yet (FR-011).
  Future<UserProfile> ensureDefault({String? userId});
}

/// SQLite-backed [UserProfileRepository].
class SqliteUserProfileRepository implements UserProfileRepository {
  SqliteUserProfileRepository(this._profileDao, this._userDao);

  final UserProfileDao _profileDao;
  final UserDao _userDao;

  @override
  Future<UserProfile?> get(String userId) =>
      runDbGuarded('PROFILE_GET', () => _profileDao.get(userId));

  @override
  Future<void> save(UserProfile profile) => runDbGuarded('PROFILE_SAVE', () async {
        await _userDao.ensure(profile.userId);
        await _profileDao.upsert(profile);
      });

  @override
  Future<bool> isOnboardingCompleted(String userId) =>
      runDbGuarded('PROFILE_ONBOARDING', () async {
        final UserProfile? profile = await _profileDao.get(userId);
        return profile?.onboardingCompleted ?? false;
      });

  @override
  Future<void> setOnboardingCompleted(String userId, bool completed) =>
      runDbGuarded('PROFILE_SET_ONBOARDING', () async {
        await _userDao.ensure(userId);
        final UserProfile? existing = await _profileDao.get(userId);
        if (existing == null) {
          await _profileDao.upsert(
            UserProfile.localDefault().copyWith(onboardingCompleted: completed),
          );
          return;
        }
        await _profileDao.setOnboardingCompleted(userId, completed);
      });

  @override
  Future<UserProfile> ensureDefault({String? userId}) =>
      runDbGuarded('PROFILE_ENSURE', () async {
        final String id = userId ?? User.localUser().id;
        await _userDao.ensure(id);
        final UserProfile? existing = await _profileDao.get(id);
        if (existing != null) {
          return existing;
        }
        final UserProfile profile = UserProfile.localDefault();
        await _profileDao.upsert(profile);
        return profile;
      });
}
