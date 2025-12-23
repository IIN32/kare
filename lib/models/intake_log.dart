import 'package:hive/hive.dart';

part 'intake_log.g.dart';

@HiveType(typeId: 1)
class IntakeLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String medicationName;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String status; // "taken_on_time", "taken_late", "skipped"

  @HiveField(4)
  final String? scheduledTime; // e.g. "08:00"

  IntakeLog({
    required this.id,
    required this.medicationName,
    required this.timestamp,
    required this.status,
    this.scheduledTime,
  });
}
