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
  DateTime? endDate;

  @HiveField(6) 
  final List<int> nagIntervals; 

  @HiveField(7)
  final String? notes;

  @HiveField(8)
  final int? totalQuantity;

  @HiveField(9)
  int? currentQuantity;

  @HiveField(10)
  final int? refillThreshold;

  @HiveField(11)
  final String? type; 
  
  @HiveField(12)
  final String profileId;

  @HiveField(13) // New Field
  bool isArchived;
  
  @HiveField(14)
  final String urgency; // "Normal", "Medium", "High"

  Medication({
    required this.name,
    required this.dosage,
    required this.times,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.nagIntervals = const [5, 10, 15],
    this.notes,
    this.totalQuantity,
    this.currentQuantity,
    this.refillThreshold,
    this.type,
    this.profileId = 'default',
    this.isArchived = false, // Default to not archived
    this.urgency = 'Normal', // Default to Normal
  });
}
