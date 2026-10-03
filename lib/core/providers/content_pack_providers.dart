/// Content-pack providers (V0.2).
///
/// Wires the offline content-pack service to the content database and exposes an
/// observable controller for the Settings screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/services/content_pack_service.dart';

/// The offline content-pack service (validation + import + reset).
final Provider<ContentPackService> contentPackServiceProvider =
    Provider<ContentPackService>(
  (Ref ref) => ContentPackService(
    contentDatabase: ref.watch(contentDatabaseProvider),
  ),
);

/// Observable state of the active content pack, for the Settings screen.
class ContentPackController extends AsyncNotifier<ContentPackInfo> {
  @override
  Future<ContentPackInfo> build() =>
      ref.read(contentPackServiceProvider).current();

  /// Validates [path] and, when valid, installs it as the active pack.
  ///
  /// Returns the validation outcome so the UI can surface the reason on failure.
  /// On success the content database is reopened for every consumer.
  Future<ContentPackValidation> importFromPath(String path) async {
    final ContentPackService service = ref.read(contentPackServiceProvider);
    final ContentPackValidation validation = await service.validate(path);
    if (!validation.ok) {
      return validation;
    }
    final ContentPackInfo info = await service.importFromPath(path);
    _refreshContentConsumers();
    state = AsyncData<ContentPackInfo>(info);
    return validation;
  }

  /// Removes any imported pack and falls back to the built-in content.
  Future<void> restoreBuiltin() async {
    final ContentPackService service = ref.read(contentPackServiceProvider);
    await service.restoreBuiltinPack();
    _refreshContentConsumers();
    state = AsyncData<ContentPackInfo>(await service.current());
  }

  /// Re-opens the content database for every consumer (vocabulary, reading, …).
  void _refreshContentConsumers() {
    ref.invalidate(contentDbProvider);
    notifyDataChanged(ref);
  }
}

/// Provider for the content-pack controller.
final AsyncNotifierProvider<ContentPackController, ContentPackInfo>
    contentPackControllerProvider =
    AsyncNotifierProvider<ContentPackController, ContentPackInfo>(
  ContentPackController.new,
);
