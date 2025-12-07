import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/local_storage_service.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../models/medication.dart';
import '../models/intake_log.dart';
import 'add_medication_screen.dart';
import 'edit_medication_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; 

  final List<Widget> _pages = [
    const MedicationsTab(),
    const HistoryScreen(), 
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Medications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class MedicationsTab extends StatefulWidget {
  const MedicationsTab({super.key});

  @override
  State<MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<MedicationsTab> {
  List<Medication> _activeMedications = [];
  final LocalStorageService _storageService = LocalStorageService();
  final LogService _logService = LogService();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  void _loadMedications() {
    setState(() {
      final allMeds = _storageService.getMedications();
      final now = DateTime.now();
      
      _activeMedications = allMeds.where((med) {
        return med.endDate == null || med.endDate!.isAfter(now);
      }).toList();
      
      _activeMedications.sort((a, b) => a.startDate.compareTo(b.startDate));
    });
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (result == true) {
      _loadMedications();
    }
  }

  Future<void> _logIntake(Medication medication, String scheduledTime) async {
    final log = IntakeLog(
      id: DateTime.now().toIso8601String(),
      medicationName: medication.name,
      timestamp: DateTime.now(),
      status: 'taken',
      scheduledTime: scheduledTime, 
    );

    await _logService.addLog(log);

    final String uniqueKey = '${medication.name}_$scheduledTime';
    final int baseId = uniqueKey.hashCode.abs();

    for (int i = 1; i <= 3; i++) {
      await _notificationService.cancelNotification(baseId + i);
    }
    
    setState(() {}); 
  }

  Future<void> _stopTreatment(Medication medication) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Treatment?'),
        content: Text('This will move "${medication.name}" to history and stop all reminders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End Now')),
        ],
      ),
    );

    if (confirm == true) {
      for (var timeString in medication.times) {
        final String uniqueKey = '${medication.name}_$timeString';
        final int baseId = uniqueKey.hashCode.abs();
        
        await _notificationService.cancelNotification(baseId); 
        for (int i = 1; i <= 3; i++) {
          await _notificationService.cancelNotification(baseId + i); 
        }
      }

      await _storageService.stopMedication(medication);
      _loadMedications();
    }
  }

  Widget _buildTimeSlots(Medication medication) {
    return Wrap(
      spacing: 4.0, // Reduced spacing
      runSpacing: 0.0,
      children: medication.times.map((timeStr) {
        final todayLogs = _logService.getLogsForMedication(medication.name).where((log) {
          final now = DateTime.now();
          return log.timestamp.year == now.year && 
                 log.timestamp.month == now.month && 
                 log.timestamp.day == now.day &&
                 log.scheduledTime == timeStr;
        }).toList();

        final bool isTaken = todayLogs.isNotEmpty;
        
        final now = TimeOfDay.now();
        final parts = timeStr.split(':');
        final scheduledH = int.parse(parts[0]);
        final scheduledM = int.parse(parts[1]);
        
        final nowMinutes = now.hour * 60 + now.minute;
        final scheduledMinutes = scheduledH * 60 + scheduledM;
        
        final bool isFuture = nowMinutes < scheduledMinutes;
        final bool isMissed = !isTaken && (nowMinutes > scheduledMinutes + 15);

        Color color = Colors.grey;
        IconData icon = Icons.check_box_outline_blank;
        String formattedTime = DateFormat.j().format(DateTime(2023, 1, 1, scheduledH, scheduledM)).toLowerCase();

        if (isTaken) {
          color = Colors.green;
          icon = Icons.check_box;
        } else if (isFuture) {
          color = Colors.grey.withOpacity(0.5); 
          icon = Icons.access_time;
        } else if (isMissed) {
          color = Colors.red;
          icon = Icons.warning_amber_rounded;
        }

        return InkWell(
          onTap: () {
            if (isTaken) {
              final log = todayLogs.first;
              final timeTaken = DateFormat.jm().format(log.timestamp);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Slot Taken at $formattedTime'),
                  content: Text('You took this at $timeTaken.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
            } else if (isFuture) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('It is not time for this dose yet.')),
              );
            } else {
              _logIntake(medication, timeStr);
            }
          },
          child: Chip(
            visualDensity: VisualDensity.compact, // Make chip smaller
            avatar: Icon(icon, color: Colors.white, size: 16),
            label: Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 12)),
            backgroundColor: color,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Medications'),
      ),
      body: _activeMedications.isEmpty
          ? const Center(
              child: Text(
                'No active medications.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _activeMedications.length,
              itemBuilder: (context, index) {
                final medication = _activeMedications[index];
                final String startStr = DateFormat.MMMd().format(medication.startDate);
                final String endStr = medication.endDate != null 
                    ? DateFormat.MMMd().format(medication.endDate!) 
                    : 'Ongoing';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.medication_liquid),
                    ),
                    title: Text(medication.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dosage: ${medication.dosage}'),
                        const SizedBox(height: 8),
                        _buildTimeSlots(medication),
                        const SizedBox(height: 8),
                        Text(
                          '$startStr — $endStr',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit, color: Colors.blueGrey),
                            label: const Text('Edit'),
                            onPressed: () => _navigateAndRefresh(
                              EditMedicationScreen(medication: medication, index: index),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.stop_circle_outlined, color: Colors.orange),
                            label: const Text('End'),
                            onPressed: () => _stopTreatment(medication),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            label: const Text('Delete'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Forever?'),
                                  content: const Text('Are you sure?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _storageService.deleteMedication(medication);
                                _loadMedications();
                              }
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(const AddMedicationScreen()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
