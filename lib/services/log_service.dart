import 'package:hive_flutter/hive_flutter.dart';
import '../models/intake_log.dart';

class LogService {
  static const String _boxName = 'intakeLogsBox';

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

  // Clear all logs
  Future<void> clearAll() async {
    await _box.clear();
  }
}
