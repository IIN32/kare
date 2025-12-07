import 'package:hive/hive.dart';

part 'medication.g.dart';

@HiveType(typeId: 0)
class Medication extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String dosage;

  @HiveField(2)
  final List<String> times; // Stored as "HH:mm" strings

  @HiveField(3)
  final int frequency;

  @HiveField(4)
  final DateTime startDate;

  @HiveField(5)
  final DateTime? endDate;

  @HiveField(6) // New Field
  final List<int> nagIntervals; // e.g., [5, 10, 15]

  Medication({
    required this.name,
    required this.dosage,
    required this.times,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.nagIntervals = const [5, 10, 15], // Default value
  });
}
