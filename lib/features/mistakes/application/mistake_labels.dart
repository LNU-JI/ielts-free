/// Presentation labels for a mistake's classification fields.
///
/// The mistake queue shows a question's *type* and *error type* (PRD §4.6). The
/// wire values come from the enums; this thin helper maps them to the localized
/// strings kept in [AppStrings], so no presentation widget needs a hard-coded
/// label or a switch over enum values.
library;

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';

/// Localized labels for the mistake taxonomy.
abstract final class MistakeLabels {
  const MistakeLabels._();

  /// Label for an [ErrorType], or `''`.
  static String errorType(ErrorType? type) => AppStrings.errorTypeLabel(type?.wire);

  /// Label for a [QuestionType], or `''`.
  static String questionType(QuestionType? type) =>
      AppStrings.questionTypeLabel(type?.wire);

  /// Label for a [SkillType], or `''`.
  static String skill(SkillType? skill) => AppStrings.skillLabel(skill?.wire);

  /// Label for a [RefType] (the filter chips of PRD §4.6).
  static String refType(RefType? refType) {
    switch (refType) {
      case RefType.vocabulary:
        return AppStrings.mistakesFilterVocabulary;
      case RefType.reading:
        return AppStrings.mistakesFilterReading;
      case null:
        return AppStrings.mistakesFilterAll;
    }
  }
}
