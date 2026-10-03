import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// Loads a topic illustration (`assets/illustrations/<slug>.webp`) and degrades
/// gracefully when it is unavailable.
///
/// The illustration files are produced separately from the code and may be
/// missing at runtime (not yet generated, or the directory not bundled). A
/// plain [Image.asset] would then show a broken-image glyph or throw; instead
/// this widget falls back to a neutral, themed placeholder so a missing
/// illustration can never break the vocabulary book (FR-030).
class TopicIllustration extends StatelessWidget {
  const TopicIllustration({
    super.key,
    required this.topic,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  /// Topic slug used to build the asset path, or `null` / empty to show the
  /// placeholder directly (e.g. while browsing "all topics").
  final String? topic;

  /// How the image fills its box.
  final BoxFit fit;

  /// Corner rounding applied to both the image and the placeholder.
  final BorderRadius borderRadius;

  /// Directory holding the per-topic illustrations (one file per slug).
  static const String assetDir = 'assets/illustrations';

  /// Builds the asset path for a topic [slug].
  static String assetPath(String slug) => '$assetDir/$slug.webp';

  @override
  Widget build(BuildContext context) {
    final String? slug = topic;
    final Widget child = (slug == null || slug.isEmpty)
        ? _placeholder(context)
        : Image.asset(
            assetPath(slug),
            fit: fit,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) =>
                _placeholder(context),
          );

    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: context.palette.muted,
        ),
      ),
    );
  }
}
