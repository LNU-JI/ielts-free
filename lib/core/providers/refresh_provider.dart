/// A single, shared "data changed" signal.
///
/// Several screens read the same user data (Dashboard, Study Plan, Settings).
/// After a write, the screen that performed it must make the others recompute
/// (docs/ARCHITECTURE-v0.1.md §9.3, FR-064).
///
/// Rather than have controllers import one another — which would create import
/// cycles (Dashboard ↔ Study Plan) — every writer bumps [dataRevisionProvider]
/// and every reader `ref.watch`es it. The integer value itself is meaningless;
/// only a *change* matters, which triggers the watchers to rebuild.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic revision counter used purely as a change notification.
final StateProvider<int> dataRevisionProvider =
    StateProvider<int>((Ref ref) => 0);

/// Signals that user data was written and downstream providers should refresh.
///
/// Call this after a successful write (goal, plan, settings, progress, …).
void notifyDataChanged(Ref ref) {
  ref.read(dataRevisionProvider.notifier).state++;
}
