/// Unit tests for [StreakService] — ARCHITECTURE §5.8.
///
/// The unit is the LOCAL calendar date, so expected dates are derived from the
/// same helper the service uses (`AppDateUtils.localDateString`) to stay
/// time-zone independent.
///
/// Note on clocks: `t0` is UTC noon, which is safe for the whole-day offsets
/// used by most cases (`add(Duration(days: n))` shifts the local date by exactly
/// `n` days in every zone). The one case that adds a *sub-day* offset
/// (`+6h`) deliberately builds its base in **local** time instead, so that
/// `+6h` can never cross local midnight (which would legitimately advance the
/// streak — e.g. UTC noon is 20:00 in UTC+8, so `+6h` lands on the next day).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/streak_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

void main() {
  // Noon UTC in mid-June avoids daylight-saving transitions in most zones.
  final DateTime t0 = DateTime.utc(2026, 6, 15, 12);

  String localDate(DateTime at) => AppDateUtils.localDateString(at);

  group('onStudyEvent', () {
    test('first ever event → streak 1', () {
      final StreakService svc = StreakService(clock: FixedClock(t0));
      final StreakResult r =
          svc.onStudyEvent(lastStudyDate: null, currentStreak: 0);
      expect(r.streak, 1);
      expect(r.lastStudyDate, localDate(t0));
      expect(r.changed, isTrue);
    });

    test('empty stored date is treated as the first event', () {
      final StreakService svc = StreakService(clock: FixedClock(t0));
      final StreakResult r =
          svc.onStudyEvent(lastStudyDate: '', currentStreak: 9);
      expect(r.streak, 1);
      expect(r.changed, isTrue);
    });

    test('same day repeated → unchanged, no double count', () {
      final StreakService svc = StreakService(clock: FixedClock(t0));
      final StreakResult r = svc.onStudyEvent(
        lastStudyDate: localDate(t0),
        currentStreak: 3,
      );
      expect(r.streak, 3);
      expect(r.lastStudyDate, localDate(t0));
      expect(r.changed, isFalse);
    });

    test('same local day, later time → unchanged', () {
      // Built in LOCAL time on purpose. A UTC base (e.g. UTC noon) can sit at
      // 20:00 local in UTC+8, so +6h would cross local midnight and the streak
      // would correctly advance — an artefact of the zone, not a bug. Local
      // 09:00 + 6h = local 15:00 stays on the same local calendar day in every
      // zone and across any DST transition.
      final DateTime base = DateTime(2026, 6, 15, 9);
      final FixedClock clock = FixedClock(base);
      final StreakService svc = StreakService(clock: clock);
      final StreakResult first =
          svc.onStudyEvent(lastStudyDate: null, currentStreak: 0);
      clock.setNow(base.add(const Duration(hours: 6)));
      final StreakResult second = svc.onStudyEvent(
        lastStudyDate: first.lastStudyDate,
        currentStreak: first.streak,
      );
      expect(second.changed, isFalse);
      expect(second.streak, 1);
    });

    test('next day → streak + 1', () {
      final DateTime tomorrow = t0.add(const Duration(days: 1));
      final StreakService svc = StreakService(clock: FixedClock(tomorrow));
      final StreakResult r = svc.onStudyEvent(
        lastStudyDate: localDate(t0),
        currentStreak: 3,
      );
      expect(r.streak, 4);
      expect(r.lastStudyDate, localDate(tomorrow));
      expect(r.changed, isTrue);
    });

    test('gap of two days → reset to 1', () {
      final DateTime later = t0.add(const Duration(days: 2));
      final StreakService svc = StreakService(clock: FixedClock(later));
      final StreakResult r = svc.onStudyEvent(
        lastStudyDate: localDate(t0),
        currentStreak: 7,
      );
      expect(r.streak, 1);
      expect(r.lastStudyDate, localDate(later));
      expect(r.changed, isTrue);
    });

    test('long gap → reset to 1', () {
      final DateTime later = t0.add(const Duration(days: 30));
      final StreakService svc = StreakService(clock: FixedClock(later));
      final StreakResult r = svc.onStudyEvent(
        lastStudyDate: localDate(t0),
        currentStreak: 12,
      );
      expect(r.streak, 1);
    });

    test('clock rollback → unchanged (no-op)', () {
      final DateTime earlier = t0.subtract(const Duration(days: 1));
      final StreakService svc = StreakService(clock: FixedClock(earlier));
      final StreakResult r = svc.onStudyEvent(
        lastStudyDate: localDate(t0),
        currentStreak: 5,
      );
      expect(r.streak, 5);
      expect(r.lastStudyDate, localDate(t0));
      expect(r.changed, isFalse);
    });
  });
}
