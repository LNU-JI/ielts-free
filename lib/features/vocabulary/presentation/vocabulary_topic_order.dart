/// Canonical browse order for vocabulary topics.
///
/// Topics are ordered by their position in [AppStrings.vocabularyTopicLabels]
/// (the contract order from `docs/VOCABULARY-TOPICS.md`), so the filter strip
/// and the detail chips read in a stable, curated order rather than by slug
/// alphabet. Any slug that is not one of the 40 canonical values is appended
/// alphabetically instead of being dropped.
library;

import 'package:ielts_free/app/strings.dart';

/// Returns [topics] in canonical topic order.
List<String> orderVocabularyTopics(List<String> topics) {
  final List<String> canonical =
      AppStrings.vocabularyTopicLabels.keys.toList(growable: false);
  final List<String> known = <String>[];
  final List<String> unknown = <String>[];
  for (final String topic in topics) {
    if (AppStrings.vocabularyTopicLabels.containsKey(topic)) {
      known.add(topic);
    } else {
      unknown.add(topic);
    }
  }
  known.sort(
    (String a, String b) =>
        canonical.indexOf(a).compareTo(canonical.indexOf(b)),
  );
  unknown.sort();
  return <String>[...known, ...unknown];
}
