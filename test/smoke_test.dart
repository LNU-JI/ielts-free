import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/app/theme.dart';

/// Minimal smoke test so `flutter test` has something to run in CI.
///
/// The full unit / data / widget / integration suites are added in T05. This
/// file only asserts that the design tokens and themes build correctly and that
/// the core constants are wired up as expected.
void main() {
  group('AppTheme', () {
    test('builds a Material 3 light theme', () {
      final ThemeData theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<AppPalette>(), isNotNull);
    });

    test('builds a Material 3 dark theme', () {
      final ThemeData theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<AppPalette>(), isNotNull);
    });
  });

  group('AppConstants', () {
    test('exposes the default local user values', () {
      expect(AppConstants.localUserId, 'local_user');
      expect(AppConstants.defaultTargetBand, 7.0);
      expect(AppConstants.defaultDailyStudyMinutes, 60);
      expect(AppConstants.defaultExamDate, isNull);
    });

    test('exposes distinct database file names', () {
      expect(
        AppConstants.contentDbFileName,
        isNot(AppConstants.userDbFileName),
      );
    });
  });
}
