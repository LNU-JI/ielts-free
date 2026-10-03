/// Writing task (content database, read-only).
///
/// Maps the `writing_tasks` table (content_pipeline/schema.sql).
///
/// Task 1 asks for a description of visual data ([chartData]); Task 2 asks for a
/// discursive essay. The model essays live in `writing_samples` and are attached
/// by the repository (see [samples]).
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/writing_sample.dart';

/// One IELTS Writing task (Task 1 or Task 2).
class WritingTask {
  const WritingTask({
    required this.id,
    required this.task,
    required this.title,
    required this.prompt,
    this.chartData,
    required this.minWords,
    required this.timeMinutes,
    this.difficulty,
    this.samples = const <WritingSample>[],
  });

  /// `writing_tasks.id`.
  final int id;

  /// Task number: 1 or 2.
  final int task;

  /// Display title.
  final String title;

  /// The full task prompt shown to the learner.
  final String prompt;

  /// Visual data for Task 1 (JSON object: labels, series, …).
  final Map<String, Object?>? chartData;

  /// Minimum word count.
  final int minWords;

  /// Suggested time in minutes.
  final int timeMinutes;

  /// Difficulty 1–5.
  final int? difficulty;

  /// The model essays for this task.
  ///
  /// **Not a column**: samples live in `writing_samples` and are attached by the
  /// repository (`WritingDao.samplesForTask`).
  final List<WritingSample> samples;

  /// Chinese label, e.g. `Task 1`.
  String get taskLabel => 'Task $task';

  /// Whether this is the Task 1 data-description task.
  bool get isTask1 => task == 1;

  /// Whether this is the Task 2 essay task.
  bool get isTask2 => task == 2;

  /// Whether the task ships visual data.
  bool get hasChartData => chartData != null && chartData!.isNotEmpty;

  /// Returns a copy with [samples] attached.
  WritingTask withSamples(List<WritingSample> samples) => WritingTask(
        id: id,
        task: task,
        title: title,
        prompt: prompt,
        chartData: chartData,
        minWords: minWords,
        timeMinutes: timeMinutes,
        difficulty: difficulty,
        samples: samples,
      );

  /// Builds a [WritingTask] from a database row / JSON object.
  factory WritingTask.fromMap(Map<String, Object?> map) => WritingTask(
        id: intOrDefault(map['id'], 0),
        task: intOrDefault(map['task'], 2),
        title: asString(map['title']) ?? '',
        prompt: asString(map['prompt']) ?? '',
        chartData: decodeMap(map['chart_data']),
        minWords: intOrDefault(map['min_words'], 0),
        timeMinutes: intOrDefault(map['time_minutes'], 0),
        difficulty: asInt(map['difficulty']),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'task': task,
        'title': title,
        'prompt': prompt,
        'chart_data': chartData == null ? null : encodeMap(chartData!),
        'min_words': minWords,
        'time_minutes': timeMinutes,
        'difficulty': difficulty,
      };
}
