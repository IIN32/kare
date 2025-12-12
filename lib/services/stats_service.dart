import 'package:collection/collection.dart';
import '../models/medication.dart';
import '../models/intake_log.dart';
import 'local_storage_service.dart';
import 'log_service.dart';

class StatsService {
  final LocalStorageService _localStorageService = LocalStorageService();
  final LogService _logService = LogService();

  //Calculating the medications for today and adherence progress as value from 0.0 to 1.0
  double getDailyProgress() {
    return _calculateAdherence(DateTime.now(), DateTime.now());
  }

  double getWeeklyProgress() {
    final now = DateTime.now();
    // Start of week (Monday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return _calculateAdherence(startOfWeek, now);
  }

  double getMonthlyProgress() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return _calculateAdherence(startOfMonth, now);
  }

  double getYearlyProgress() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    return _calculateAdherence(startOfYear, now);
  }

  double _calculateAdherence(DateTime start, DateTime end) {
    final allMeds = _localStorageService.getMedications();
    final allLogs = _logService.getLogs();

    int totalScheduled = 0;
    int totalTaken = 0;

    // Normalize dates to start of day to avoid time issues
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    final daysDifference = endDay.difference(startDay).inDays;

    for (int i = 0; i <= daysDifference; i++) {
      final currentDay = startDay.add(Duration(days: i));
      
      // 1. Calculate Scheduled for this day
      for (var med in allMeds) {
        // Check if med is active on 'currentDay'
        // Med is active if startDate <= currentDay AND (endDate == null OR endDate >= currentDay)
        
        final startM = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
        final endM = med.endDate != null ? DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day) : null;

        bool isActive = (startM.isBefore(currentDay) || isSameDay(startM, currentDay)) &&
                        (endM == null || endM.isAfter(currentDay) || isSameDay(endM, currentDay));
        
        if (isActive) {
          totalScheduled += med.times.length;
        }
      }

      // 2. Calculate Taken for this day
      final logsForDay = allLogs.where((log) => isSameDay(log.timestamp, currentDay));
      // Unique taken count (medication + scheduled time)
      final uniqueTaken = logsForDay
          .map((log) => '${log.medicationName}_${log.scheduledTime}')
          .toSet()
          .length;
      
      totalTaken += uniqueTaken;
    }

    if (totalScheduled == 0) return 0.0;
    
    // Cap at 1.0 just in case of weird data
    double progress = totalTaken / totalScheduled;
    return progress > 1.0 ? 1.0 : progress;
  }

  //Checking function to check if 2 DateTime object are refering the same calendar
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
