import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stats_service.dart';
import '../services/local_storage_service.dart';
import '../models/medication.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  //Initializing services
  final StatsService _statsService= StatsService();
  final LocalStorageService _localStorageService = LocalStorageService();
  
  //Stats variable store
  double _dailyProgress = 0.0;
  double _weeklyProgress = 0.0;
  double _monthlyProgress = 0.0;
  double _yearlyProgress = 0.0;

  //Upcoming Medications
  List<Medication> _upcomingMeds = [];
  
  @override
  void initState() {
    super.initState();
    _loadStats();//For data loading at screen start
  }

  //Fetching data and updating UI
  void _loadStats() {
    setState(() {
      _dailyProgress = _statsService.getDailyProgress();
      _weeklyProgress = _statsService.getWeeklyProgress();
      _monthlyProgress = _statsService.getMonthlyProgress();
      _yearlyProgress = _statsService.getYearlyProgress();
      
      _upcomingMeds = _getUpcomingMeds(); //For up coming Medications
    });
  }

  //Finding medication logic
  List<Medication> _getUpcomingMeds() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final allMeds = _localStorageService.getMedications();
    final List<Medication> upcoming = [];

    // Filter for medications that have a scheduled time later today
    for (var med in allMeds) {
      // Checking if med is active today
      if (med.endDate != null && med.endDate!.isBefore(DateTime.now())) continue;

      for (var timeStr in med.times) {
        final parts = timeStr.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final medMinutes = h * 60 + m;

        // If the scheduled time is in the future
        if (medMinutes > nowMinutes) {
          upcoming.add(med);
          break; // Only add the medication once, even if it has multiple future doses
        }
      }
    }
    return upcoming;
  }

  Widget _buildProgressBar(String label, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
            Text('${(progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      // RefreshIndicator lets the user pull down to update stats
      body: RefreshIndicator(
        onRefresh: () async => _loadStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. DATE HEADER
              Text(
                DateFormat.MMMMEEEEd().format(DateTime.now()), // e.g., "Friday, Nov 10"
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 2. PROGRESS RING CARD (Daily)
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Circle (Grey)
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: 1.0, // Full circle
                        strokeWidth: 12,
                        color: Colors.grey[200],
                      ),
                    ),
                    // Foreground Progress (Blue/Green)
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: _dailyProgress, // Our calculated value
                        strokeWidth: 12,
                        backgroundColor: Colors.transparent,
                        color: _dailyProgress >= 1.0 ? Colors.green : Colors.blue,
                        strokeCap: StrokeCap.round, // Rounded ends look nicer
                      ),
                    ),
                    // Text in the Middle
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
              ),
              const SizedBox(height: 32),

              // 3. WEEKLY / MONTHLY / YEARLY SUMMARY
              const Text(
                'Adherence Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    _buildProgressBar('This Week', _weeklyProgress, Colors.orangeAccent),
                    const SizedBox(height: 16),
                    _buildProgressBar('This Month', _monthlyProgress, Colors.deepPurpleAccent),
                    const SizedBox(height: 16),
                    _buildProgressBar('This Year', _yearlyProgress, Colors.teal),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4. UPCOMING MEDS SECTION
              const Text(
                'Upcoming Today',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
                //Making medication list dynamic
                _upcomingMeds.isEmpty
                    ? Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No more meds for today!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
                    : Column(
                  children: _upcomingMeds.map((med) => Card(
                    elevation: 0,
                    color: Colors.blue[50],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.access_time, color: Colors.blue),
                      title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(med.dosage),
                    ),
                  )).toList(),
                )
            ],
          ),
        ),
      ),
    );
  }
}
