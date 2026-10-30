import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quran_center/data/models/app_model.dart';

/// Helpers for converting between model JSON maps (DateTime as ms ints) and
/// Firestore-compatible maps (proper [Timestamp] / [FieldValue]).
class FirestoreConverter {
  const FirestoreConverter();

  /// Encode [DateTime] values in [data] to Firestore [Timestamp] objects so
  /// they are queryable and stored with proper type.
  ///
  /// [timestampKeys] are the map keys holding DateTime/milliseconds values.
  JsonMap encodeForWrite(JsonMap data, {Iterable<String> timestampKeys = const []}) {
    final result = <String, dynamic>{};
    final tsKeys = timestampKeys.toSet();
    data.forEach((key, value) {
      if (tsKeys.contains(key)) {
        if (value is DateTime) {
          result[key] = Timestamp.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);
        } else if (value is int) {
          result[key] = Timestamp.fromMillisecondsSinceEpoch(value);
        } else {
          result[key] = value;
        }
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  /// A [Timestamp] for [value].
  Timestamp timestampOf(DateTime value) =>
      Timestamp.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);

  /// Server timestamp sentinel for createdAt/updatedAt on write.
  FieldValue serverTimestamp() => FieldValue.serverTimestamp();

  /// Decode a Firestore document snapshot data into a [JsonMap] where
  /// [Timestamp] values are converted to [DateTime] (for model fromJson).
  JsonMap decodeFromRead(Map<String, dynamic>? data) {
    if (data == null) return {};
    return {for (final e in data.entries) e.key: _decode(e.value)};
  }

  /// Converts [Timestamp]s to [DateTime] at any depth, so nested values (for
  /// example a task's `teacherVerification.verifiedAt`) are read correctly.
  dynamic _decode(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is Map) {
      return {for (final e in value.entries) e.key as String: _decode(e.value)};
    }
    if (value is List) return [for (final v in value) _decode(v)];
    return value;
  }
}

final firestoreConverter = FirestoreConverter();
