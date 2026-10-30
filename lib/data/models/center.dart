/// A minimal center record (placeholder for future expansion).
/// Multi-branch is out of scope but the structure supports a centerId association.
import 'package:quran_center/data/models/app_model.dart';

class Center extends AppModel {
  const Center({
    required this.centerId,
    required this.name,
    this.logoUrl,
    this.contact,
    this.timezone = 'UTC',
    this.locale = 'ar',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  final String centerId;
  final String name;
  final String? logoUrl;
  final Map<String, String>? contact; // {phone?, email?, address?}
  final String timezone;
  final String locale;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Center.fromJson(String centerId, JsonMap json) {
    return Center(
      centerId: centerId,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
      contact: (json['contact'] as JsonMap?)
          ?.map((k, v) => MapEntry(k, v as String)),
      timezone: json['timezone'] as String? ?? 'UTC',
      locale: json['locale'] as String? ?? 'ar',
      status: json['status'] as String? ?? 'active',
      createdAt: AppModel.parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: AppModel.parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  JsonMap toJson() {
    return {
      'name': name,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (contact != null) 'contact': contact,
      'timezone': timezone,
      'locale': locale,
      'status': status,
      'createdAt': AppModel.encodeDateTime(createdAt),
      'updatedAt': AppModel.encodeDateTime(updatedAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Center &&
          runtimeType == other.runtimeType &&
          centerId == other.centerId;

  @override
  int get hashCode => centerId.hashCode;

  @override
  String toString() => 'Center(centerId: $centerId, name: $name)';
}
