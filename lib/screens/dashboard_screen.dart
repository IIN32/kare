import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stats_service.dart';
import '../services/local_storage_service.dart';
import '../services/profile_service.dart';
import '../services/log_service.dart';
import '../models/medication.dart';
import 'history_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMedications;
  const DashboardScreen({super.key, this.onNavigateToMedications});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StatsService _statsService= StatsService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final ProfileService _profileService = ProfileService();
  final LogService _logService = LogService();
  
  double _dailyProgress = 0.0;
  DoseCount _doseCount = DoseCount(taken: 0, scheduled: 0);
  double _weeklyProgress = 0.0;
  double _monthlyProgress = 0.0;
  double _yearlyProgress = 0.0;
  int _streak = 0;
  int _points = 0;
  Map<DateTime, double> _heatmapData = {};
  String? _adherenceInsight;
  String _motivationalMessage = '';

  List<Map<String, dynamic>> _upcomingMeds = [];
  List<Map<String, dynamic>> _missedMeds = [];
  List<Medication> _lowStockMeds = [];
  
  @override
  void initState() {
    super.initState();
    _profileService.addListener(_loadStats);
    _logService.addListener(_loadStats);
    _loadStats();
  }

  @override
  void dispose() {
    _profileService.removeListener(_loadStats);
    _logService.removeListener(_loadStats);
    super.dispose();
  }

  void _loadStats() {
    final profileId = _profileService.currentProfileId;
    setState(() {
      _dailyProgress = _statsService.getDailyProgress(profileId);
      _doseCount = _statsService.getDailyDoseCounts(profileId);
      _weeklyProgress = _statsService.getWeeklyProgress(profileId);
      _monthlyProgress = _statsService.getMonthlyProgress(profileId);
      _yearlyProgress = _statsService.getYearlyProgress(profileId);
      _streak = _statsService.getCurrentStreak(profileId);
      _points = _profileService.points;
      _heatmapData = _statsService.getAdherenceForLastYear(profileId);
      _adherenceInsight = _statsService.getAdherenceInsight(profileId);
      _upcomingMeds = _getUpcomingMeds(profileId);
      _missedMeds = _getMissedMeds(profileId);
      _lowStockMeds = _getLowStockMeds(profileId);

      // Calculate Motivational Message
      if (_dailyProgress >= 1.0 && _doseCount.scheduled > 0) {
        _motivationalMessage = "🎉 Amazing! You've completed all your meds today.";
      } else if (_dailyProgress >= 0.5) {
        _motivationalMessage = "👍 Great job! You're halfway there.";
      } else if (_dailyProgress > 0) {
        _motivationalMessage = "🚀 Off to a good start! Keep it up.";
      } else {
        _motivationalMessage = "👋 Don't forget your meds today. You got this!";
      }
    });
  }

  bool _isTaken(String medName, String timeStr) {
      final todayLogs = _logService.getLogsForMedication(medName).where((log) {
          final now = DateTime.now();
          return log.timestamp.year == now.year && 
                 log.timestamp.month == now.month && 
                 log.timestamp.day == now.day &&
                 log.scheduledTime == timeStr;
      });
      return todayLogs.isNotEmpty;
  }

  List<Map<String, dynamic>> _getUpcomingMeds(String profileId) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final allMeds = _localStorageService.getMedications().where((med) => med.profileId == profileId && !med.isArchived).toList();
    final List<Map<String, dynamic>> upcoming = [];

    for (var med in allMeds) {
      if (med.endDate != null && med.endDate!.isBefore(DateTime.now())) continue;

      for (var timeStr in med.times) {
        if (_isTaken(med.name, timeStr)) continue;

        final parts = timeStr.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final medMinutes = h * 60 + m;

        if (medMinutes > nowMinutes) {
          upcoming.add({'med': med, 'time': timeStr});
        }
      }
    }
    upcoming.sort((a, b) {
        final t1 = (a['time'] as String).split(':');
        final t2 = (b['time'] as String).split(':');
        final m1 = int.parse(t1[0]) * 60 + int.parse(t1[1]);
        final m2 = int.parse(t2[0]) * 60 + int.parse(t2[1]);
        return m1.compareTo(m2);
    });
    return upcoming;
  }

  List<Map<String, dynamic>> _getMissedMeds(String profileId) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final allMeds = _localStorageService.getMedications().where((med) => med.profileId == profileId && !med.isArchived).toList();
    final List<Map<String, dynamic>> missed = [];

    for (var med in allMeds) {
      if (med.endDate != null && med.endDate!.isBefore(DateTime.now())) continue;

      for (var timeStr in med.times) {
        if (_isTaken(med.name, timeStr)) continue;

        final parts = timeStr.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final medMinutes = h * 60 + m;

        if (medMinutes <= nowMinutes) {
           missed.add({'med': med, 'time': timeStr});
        }
      }
    }
    missed.sort((a, b) {
        final t1 = (a['time'] as String).split(':');
        final t2 = (b['time'] as String).split(':');
        final m1 = int.parse(t1[0]) * 60 + int.parse(t1[1]);
        final m2 = int.parse(t2[0]) * 60 + int.parse(t2[1]);
        return m1.compareTo(m2);
    });
    return missed;
  }

  List<Medication> _getLowStockMeds(String profileId) {
    final allMeds = _localStorageService.getMedications().where((med) => med.profileId == profileId).toList();
    return allMeds.where((med) {
      return med.currentQuantity != null &&
             med.refillThreshold != null &&
             med.currentQuantity! <= med.refillThreshold!;
    }).toList();
  }

  Widget _buildProgressBar(String label, double progress, Color color, HistoryPeriod period) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HistoryScreen(initialPeriod: period)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodySmall?.color)),
              Text('${(progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(50),
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressBars() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildProgressBar('Weekly Progress', _weeklyProgress, Colors.green, HistoryPeriod.week),
          const SizedBox(height: 16),
          _buildProgressBar('Monthly Progress', _monthlyProgress, Colors.orange, HistoryPeriod.month),
          const SizedBox(height: 16),
          _buildProgressBar('Yearly Progress', _yearlyProgress, Colors.red, HistoryPeriod.year),
        ],
      ),
    );
  }

  Widget _buildHeatmap() {
    return Container(
      padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildHeatmapGrid(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less', style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 4),
              Container(width: 10, height: 10, color: Colors.green.shade200),
              const SizedBox(width: 4),
              Container(width: 10, height: 10, color: Colors.green.shade400),
              const SizedBox(width: 4),
              Container(width: 10, height: 10, color: Colors.green.shade600),
              const SizedBox(width: 4),
              const Text('More', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    final now = DateTime.now();
    final daysToShow = 35; 
    final currentSunday = now.subtract(Duration(days: now.weekday % 7));
    final startDate = currentSunday.subtract(const Duration(days: 28));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            Text('Sun', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Mon', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Tue', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Wed', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Thu', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Fri', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Sat', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, 
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: daysToShow, 
          itemBuilder: (context, index) {
            final cellDate = startDate.add(Duration(days: index));
            final adherence = _heatmapData[DateTime(cellDate.year, cellDate.month, cellDate.day)] ?? 0.0;

            Color color;
            if (cellDate.isAfter(now)) {
               color = Colors.transparent;
            } else if (adherence >= 1.0) {
              color = Colors.green.shade600;
            } else if (adherence >= 0.5) {
              color = Colors.green.shade400;
            } else if (adherence > 0) {
              color = Colors.green.shade200;
            } else {
              color = Colors.grey.withAlpha(50); 
            }

            return Tooltip(
              message: '${DateFormat.yMMMd().format(cellDate)}: ${(adherence * 100).toInt()}% Taken',
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRefillCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Refill Soon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
          const SizedBox(height: 8),
          ..._lowStockMeds.map((med) => 
            Text('- ${med.name} (${med.currentQuantity} left)', style: TextStyle(color: Colors.orange.shade900)))
        ],
      ),
    );
  }

   Widget _buildInsightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
          const SizedBox(height: 8),
          Text(_adherenceInsight!, style: TextStyle(color: Colors.blue.shade900, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
  
  Widget _buildMotivationalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(75), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _motivationalMessage,
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderList(String title, List<Map<String, dynamic>> items, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
             children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
             ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
             const Text("No items.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ...items.map((item) {
             final med = item['med'] as Medication;
             final time = item['time'] as String;
             
             // Convert '13:00' to '1:00 PM'
             final parts = time.split(':');
             final dt = DateTime(2022,1,1, int.parse(parts[0]), int.parse(parts[1]));
             final formattedTime = DateFormat.jm().format(dt);

             return InkWell(
               onTap: widget.onNavigateToMedications,
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 4.0),
                 child: Row(
                   children: [
                     const Icon(Icons.circle, size: 8, color: Colors.grey),
                     const SizedBox(width: 8),
                     Expanded(child: Text('${med.name} at $formattedTime', style: const TextStyle(fontWeight: FontWeight.w500))),
                     const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                   ],
                 ),
               ),
             );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat.MMMMEEEEd().format(DateTime.now()), 
                    style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: _streak > 0 ? Colors.orange : Colors.grey),
                      const SizedBox(width: 4),
                      Text('$_streak Days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 16),
                      Icon(Icons.star_rounded, color: _points > 0 ? Colors.amber : Colors.grey),
                      const SizedBox(width: 4),
                      Text('$_points', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (_motivationalMessage.isNotEmpty) ...[
                 _buildMotivationalCard(),
                 const SizedBox(height: 20),
              ],

              if (_missedMeds.isNotEmpty) ...[
                 _buildReminderList('Missed Medications', _missedMeds, Colors.red, Icons.warning_amber_rounded),
                 const SizedBox(height: 20),
              ],
              
              if (_upcomingMeds.isNotEmpty) ...[
                 _buildReminderList('Upcoming Medications', _upcomingMeds, Colors.blue, Icons.access_time),
                 const SizedBox(height: 20),
              ],

              if (_lowStockMeds.isNotEmpty) ...[
                _buildRefillCard(),
                const SizedBox(height: 20),
              ],

              if (_adherenceInsight != null) ...[
                _buildInsightCard(),
                const SizedBox(height: 20),
              ],

              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: 1.0, 
                            strokeWidth: 12,
                            color: Theme.of(context).colorScheme.surface.withAlpha(50),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: _dailyProgress,
                            strokeWidth: 12,
                            backgroundColor: Colors.transparent,
                            color: _dailyProgress >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(_dailyProgress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            const Text('Taken', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_doseCount.scheduled > 0)
                      Text('${_doseCount.taken} of ${_doseCount.scheduled} doses taken', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildHeatmap(),
              const SizedBox(height: 20),

              // _buildProgressBars(), // Commented out for future use
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
