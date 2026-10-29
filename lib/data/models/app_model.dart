/// Base type for all domain models.
///
/// Models are pure Dart (no Firebase types) so they can be tested without the
/// Firebase SDK. Timestamps are [DateTime]; conversion to/from Firestore
/// [Timestamp] happens at the datasource/repository boundary.
typedef JsonMap = Map<String, dynamic>;

abstract class AppModel {
  const AppModel();

  JsonMap toJson();

  /// Parses a JSON value (int ms, double, ISO string, or DateTime) into [DateTime].
  /// Returns null if the value is null or absent.
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) {
      try {
        return DateTime.parse(value);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// Encodes [dateTime] to milliseconds since epoch (JSON-safe).
  static int? encodeDateTime(DateTime? dateTime) =>
      dateTime?.millisecondsSinceEpoch;
}
