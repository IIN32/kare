import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/intake_log.dart';
import 'profile_service.dart';

class LogService with ChangeNotifier {
  static const String _boxName = 'intakeLogsBox';
  // Singleton pattern
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final ProfileService _profileService = ProfileService();

  // Initialize Hive box for logs
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(IntakeLogAdapter());
    }
    await Hive.openBox<IntakeLog>(_boxName);
  }

  Box<IntakeLog> get _box => Hive.box<IntakeLog>(_boxName);

  // Add a log entry
  Future<void> addLog(IntakeLog log) async {
    await _box.add(log);

    // Award points
    if (log.status == 'taken_on_time') {
      _profileService.addPoints(10);
    } else if (log.status == 'taken_late') {
      _profileService.addPoints(5);
    }

    notifyListeners();
  }

  // Get all logs, sorted by newest first
  List<IntakeLog> getLogs() {
    final logs = _box.values.toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  // Get logs for a specific medication
  List<IntakeLog> getLogsForMedication(String medName) {
    return _box.values
        .where((log) => log.medicationName == medName)
        .toList();
  }

  // Delete all logs for a specific medication on a specific day
  Future<void> deleteLogsForMedicationOnDay(String medName, DateTime day) async {
    final Map<dynamic, IntakeLog> map = _box.toMap();
    final List<dynamic> keysToDelete = [];
    
    map.forEach((key, value) {
      if (value.medicationName == medName &&
          value.timestamp.year == day.year &&
          value.timestamp.month == day.month &&
          value.timestamp.day == day.day) {
        keysToDelete.add(key);
      }
    });
    
    if (keysToDelete.isNotEmpty) {
      await _box.deleteAll(keysToDelete);
      notifyListeners();
    }
  }

  // Clear all logs
  Future<void> clearAll() async {
    await _box.clear();
    notifyListeners();
  }
}
