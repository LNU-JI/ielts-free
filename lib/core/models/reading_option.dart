/// Reading answer option (content database, read-only).
///
/// Maps the `reading_options` table (docs/ARCHITECTURE-v0.1.md §4.2).
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// A selectable option for a choice-style question.
class ReadingOption {
  const ReadingOption({
    this.id,
    required this.questionId,
    this.orderIndex,
    this.label,
    required this.content,
    this.isCorrect,
  });

  /// `reading_options.id`.
  final int? id;

  /// Owning question id.
  final int questionId;

  /// Display order (1-based).
  final int? orderIndex;

  /// Option label, e.g. `A` / `B` / heading number.
  final String? label;

  /// Option text.
  final String content;

  /// Whether this option is the correct one.
  final bool? isCorrect;

  /// Builds a [ReadingOption] from a database row / JSON object.
  factory ReadingOption.fromMap(Map<String, Object?> map) => ReadingOption(
        id: asInt(map['id']),
        questionId: intOrDefault(map['question_id'], 0),
        orderIndex: asInt(map['order_index']),
        label: asString(map['label']),
        content: asString(map['content']) ?? '',
        isCorrect: map.containsKey('is_correct')
            ? asBool(map['is_correct'])
            : null,
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'question_id': questionId,
        'order_index': orderIndex,
        'label': label,
        'content': content,
        'is_correct': isCorrect == null ? null : (isCorrect! ? 1 : 0),
      };
}
