/// Safe conversions between SQLite / JSON values and Dart types.
///
/// ## Why this exists
///
/// With `strict-casts: true` the analyzer forbids implicit downcasts, so
/// `jsonDecode(...)` results and `Map<String, Object?>` values must be narrowed
/// explicitly. These helpers centralise that narrowing so every model's
/// `fromMap` / `toMap` stays short and consistent (ARCHITECTURE §9.7).
library;

import 'dart:convert';

/// Reads [value] as an `int`, or `null`.
int? asInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// Reads [value] as a `double`, or `null`.
double? asDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

/// Reads [value] as a `bool` (SQLite stores booleans as `0`/`1`).
bool asBool(Object? value, {bool fallback = false}) {
  if (value == null) {
    return fallback;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String text = value.toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }
  return fallback;
}

/// Reads [value] as a `String`, or `null`.
String? asString(Object? value) {
  if (value == null) {
    return null;
  }
  return value is String ? value : value.toString();
}

/// Reads [value] as an `int`, or [fallback] when null / unparsable.
int intOrDefault(Object? value, int fallback) => asInt(value) ?? fallback;

/// Reads [value] as a `double`, or [fallback] when null / unparsable.
double doubleOrDefault(Object? value, double fallback) =>
    asDouble(value) ?? fallback;

/// Decodes a JSON string (or an already-decoded list) into a `List<Object?>`.
List<Object?> _decodeList(Object? raw) {
  if (raw == null) {
    return const <Object?>[];
  }
  Object? decoded = raw;
  if (raw is String) {
    final String text = raw.trim();
    if (text.isEmpty) {
      return const <Object?>[];
    }
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return const <Object?>[];
    }
  }
  if (decoded is List<Object?>) {
    return List<Object?>.from(decoded);
  }
  return const <Object?>[];
}

/// Decodes a JSON array of strings.
List<String> decodeStringList(Object? raw) => _decodeList(raw)
    .map((Object? e) => e?.toString() ?? '')
    .where((String e) => e.isNotEmpty)
    .toList(growable: false);

/// Decodes a JSON array of string arrays (e.g. synonym pairs).
List<List<String>> decodeStringMatrix(Object? raw) => _decodeList(raw)
    .map((Object? row) {
      if (row is List<Object?>) {
        return row
            .map((Object? e) => e?.toString() ?? '')
            .where((String e) => e.isNotEmpty)
            .toList(growable: false);
      }
      final String single = row?.toString() ?? '';
      return single.isEmpty ? const <String>[] : <String>[single];
    })
    .toList(growable: false);

/// Decodes a JSON array of objects into `List<Map<String, Object?>>`.
List<Map<String, Object?>> decodeMapList(Object? raw) => _decodeList(raw)
    .whereType<Map<Object?, Object?>>()
    .map(_stringKeyed)
    .toList(growable: false);

/// Decodes a JSON object into `Map<String, Object?>`, or `null`.
Map<String, Object?>? decodeMap(Object? raw) {
  if (raw == null) {
    return null;
  }
  Object? decoded = raw;
  if (raw is String) {
    final String text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
  if (decoded is Map<Object?, Object?>) {
    return _stringKeyed(decoded);
  }
  return null;
}

Map<String, Object?> _stringKeyed(Map<Object?, Object?> source) =>
    source.map((Object? k, Object? v) => MapEntry(k.toString(), v));

/// Encodes a list of strings as a JSON array string.
String encodeStringList(List<String> values) => jsonEncode(values);

/// Encodes a list of string lists as a JSON array-of-arrays string.
String encodeStringMatrix(List<List<String>> values) => jsonEncode(values);

/// Encodes a map as a JSON object string.
String encodeMap(Map<String, Object?> value) => jsonEncode(value);

/// Encodes a list of maps as a JSON array string.
String encodeMapList(List<Map<String, Object?>> values) => jsonEncode(values);
