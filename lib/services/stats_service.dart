import 'package:collection/collection.dart';
import '../models/medication.dart';
import '../models/intake_log.dart';
import 'local_storage_service.dart';
import 'log_service.dart';

class DoseCount {
  final int taken;
  final int scheduled;
  DoseCount({required this.taken, required this.scheduled});
}

class StatsService {
  final LocalStorageService _localStorageService = LocalStorageService();
  final LogService _logService = LogService();

  List<Medication> _getMedicationsForProfile(String profileId) {
    return _localStorageService.getMedications().where((med) => med.profileId == profileId && !med.isArchived).toList();
  }

  DoseCount getDailyDoseCounts(String profileId) {
    final today = DateTime.now();
    final profileMeds = _getMedicationsForProfile(profileId);
    final allLogs = _logService.getLogs();

    int scheduled = 0;
    for (var med in profileMeds) {
      if (_isMedActiveOnDay(med, today)) {
        scheduled += med.times.length;
      }
    }

    final logsForDay = allLogs.where((log) => 
      isSameDay(log.timestamp, today) && 
      profileMeds.any((m) => m.name == log.medicationName)
    );

    final taken = logsForDay.map((log) => '${log.medicationName}_${log.scheduledTime}').toSet().length;

    return DoseCount(taken: taken, scheduled: scheduled);
  }

  double getDailyProgress(String profileId) {
    final counts = getDailyDoseCounts(profileId);
    if (counts.scheduled == 0) return 0.0;
    return counts.taken / counts.scheduled;
  }

  double getWeeklyProgress(String profileId) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return _calculateAdherence(startOfWeek, now, profileId);
  }

  double getMonthlyProgress(String profileId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return _calculateAdherence(startOfMonth, now, profileId);
  }

  double getYearlyProgress(String profileId) {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    return _calculateAdherence(startOfYear, now, profileId);
  }

  int getCurrentStreak(String profileId) {
    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; ; i++) {
      final day = today.subtract(Duration(days: i));
      final medsForProfileOnDay = _getMedicationsForProfile(profileId)
          .where((med) => _isMedActiveOnDay(med, day))
          .toList();

      if (medsForProfileOnDay.isEmpty) {
        if (i > 0) break; 
      }

      double adherence = _calculateAdherence(day, day, profileId);
      if (adherence >= 1.0) {
        streak++;
      } else {
        if (i > 0) break; 
      }
    }
    
    return streak;
  }
  
  Map<DateTime, double> getAdherenceForLastYear(String profileId) {
    final Map<DateTime, double> map = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (int i = 0; i < 365; i++) {
      final day = today.subtract(Duration(days: i));
      map[day] = _calculateAdherence(day, day, profileId);
    }
    return map;
  }

  String? getAdherenceInsight(String profileId) {
    final profileMeds = _getMedicationsForProfile(profileId);
    if (profileMeds.isEmpty) return null;

    final allLogs = _logService.getLogs();
    final Map<String, int> missedCounts = {};

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    for (var med in profileMeds) {
      for (var timeStr in med.times) {
        for (int i = 0; i < 30; i++) {
          final day = thirtyDaysAgo.add(Duration(days: i));
          if (_isMedActiveOnDay(med, day)) {
            final wasTaken = allLogs.any((log) => 
              isSameDay(log.timestamp, day) && 
              log.medicationName == med.name && 
              log.scheduledTime == timeStr);

            if (!wasTaken) {
              final hour = int.parse(timeStr.split(':')[0]);
              String timeOfDay;
              if (hour < 12) {
                timeOfDay = 'Morning';
              } else if (hour < 17) {
                timeOfDay = 'Afternoon';
              } else {
                timeOfDay = 'Evening';
              }
              missedCounts[timeOfDay] = (missedCounts[timeOfDay] ?? 0) + 1;
            }
          }
        }
      }
    }

    if (missedCounts.isEmpty) return null;

    final sortedMisses = missedCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final mostMissed = sortedMisses.first;

    if (mostMissed.value > 5) { 
      return 'You most often miss your ${mostMissed.key.toLowerCase()} doses.';
    }

    return null;
  }

  bool _isMedActiveOnDay(Medication med, DateTime day) {
    final startM = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
    final endM = med.endDate != null ? DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day) : null;

    return (startM.isBefore(day) || isSameDay(startM, day)) &&
           (endM == null || endM.isAfter(day) || isSameDay(endM, day));
  }

  double _calculateAdherence(DateTime start, DateTime end, String profileId) {
    final profileMeds = _getMedicationsForProfile(profileId);
    final allLogs = _logService.getLogs();

    int totalScheduled = 0;
    int totalTaken = 0;

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    for (int i = 0; i <= endDay.difference(startDay).inDays; i++) {
      final currentDay = startDay.add(Duration(days: i));
      
      for (var med in profileMeds) {
        if (_isMedActiveOnDay(med, currentDay)) {
          totalScheduled += med.times.length;
        }
      }

      final logsForDay = allLogs.where((log) => 
          isSameDay(log.timestamp, currentDay) && 
          profileMeds.any((m) => m.name == log.medicationName)
      );

      final uniqueTaken = logsForDay
          .map((log) => '${log.medicationName}_${log.scheduledTime}')
          .toSet()
          .length;
      
      totalTaken += uniqueTaken;
    }

    if (totalScheduled == 0) return 0.0;
    
    double progress = totalTaken / totalScheduled;
    return progress > 1.0 ? 1.0 : progress;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
