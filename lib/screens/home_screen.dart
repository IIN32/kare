import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../models/medication.dart';
import '../models/intake_log.dart';
import '../models/profile.dart';
import '../widgets/medication_cards.dart';
import './dashboard_screen.dart';
import 'add_medication_screen.dart';
import 'edit_medication_screen.dart';
import 'history_screen.dart';
import 'medication_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; 

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardScreen(onNavigateToMedications: () => _onTabTapped(1)),
      const MedicationsTab(),
      const HistoryScreen(), 
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Medications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
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
  List<Medication> _inactiveMedications = [];
  final LocalStorageService _storageService = LocalStorageService();
  final LogService _logService = LogService();
  final NotificationService _notificationService = NotificationService();
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _profileService.addListener(_loadMedications);
    _logService.addListener(_loadMedications); // Listen to log changes
    _loadMedications();
  }
  
  @override
  void dispose() {
    _profileService.removeListener(_loadMedications);
    _logService.removeListener(_loadMedications); // Remove listener
    super.dispose();
  }

  void _loadMedications() {
    setState(() {
      final allMeds = _storageService.getMedications().where((med) => med.profileId == _profileService.currentProfileId && !med.isArchived).toList();
      final now = DateTime.now();
      
      _activeMedications = allMeds.where((med) {
        return med.endDate == null || med.endDate!.isAfter(now);
      }).toList();
      _activeMedications.sort((a, b) => a.startDate.compareTo(b.startDate));
      
      _inactiveMedications = allMeds.where((med) {
        return med.endDate != null && med.endDate!.isBefore(now);
      }).toList();
      _inactiveMedications.sort((a, b) => b.endDate!.compareTo(a.endDate!));
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

  Future<void> _logIntake(Medication medication, String scheduledTime, String? notes) async {
    // Calculate status
    final timeParts = scheduledTime.split(':');
    final sh = int.parse(timeParts[0]);
    final sm = int.parse(timeParts[1]);
    final now = DateTime.now();
    
    DateTime scheduledDateTime = DateTime(now.year, now.month, now.day, sh, sm);
    Duration diff = now.difference(scheduledDateTime);
    
    if (diff.inHours < -12) {
       scheduledDateTime = scheduledDateTime.subtract(const Duration(days: 1));
       diff = now.difference(scheduledDateTime);
    }
    
    String status = 'taken_on_time';
    if (diff.inMinutes > 30) {
      status = 'taken_late';
    }

    final log = IntakeLog(
      id: DateTime.now().toIso8601String(),
      medicationName: medication.name,
      timestamp: DateTime.now(),
      status: status,
      scheduledTime: scheduledTime, 
      notes: notes,
    );

    await _logService.addLog(log);

    if (medication.currentQuantity != null && medication.currentQuantity! > 0) {
      medication.currentQuantity = medication.currentQuantity! - 1;
      await medication.save(); 

      if (medication.refillThreshold != null && medication.currentQuantity! <= medication.refillThreshold!) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Refill Alert: Only ${medication.currentQuantity} ${medication.name} left!'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        _notificationService.showNotification(
          id: 99999 + medication.hashCode, 
          title: 'Refill Needed: ${medication.name}',
          body: 'You have ${medication.currentQuantity} doses left.',
        );
      }
    }

    // Correctly generate the specific ID for the notification that was tapped.
    final String uniqueKey = '${medication.name}_$scheduledTime';
    final int baseId = uniqueKey.hashCode.abs();

    // Cancel the main notification for this specific time
    await _notificationService.cancelNotification(baseId);

    // Cancel all potential nag notifications for this specific time
    for (int i = 1; i <= 15; i++) {
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
        for (int i = 1; i <= 15; i++) {
          await _notificationService.cancelNotification(baseId + i); 
        }
      }

      await _storageService.stopMedication(medication);
      _loadMedications();
    }
  }
  
  Future<void> _restoreTreatment(Medication medication) async {
    await _storageService.restoreMedication(medication);
    _loadMedications();
  }

  Widget _buildProfileSwitcher() {
    final profiles = _profileService.getProfiles();
    final currentProfile = _profileService.currentProfileId;

    return DropdownButton<String>(
      value: currentProfile,
      icon: const Icon(Icons.person, color: Colors.white),
      underline: Container(),
      onChanged: (String? newProfileId) {
        if (newProfileId != null) {
          _profileService.setCurrentProfile(newProfileId);
        }
      },
      items: profiles.map<DropdownMenuItem<String>>((Profile profile) {
        return DropdownMenuItem<String>(
          value: profile.id,
          child: Text(profile.name),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          _buildProfileSwitcher(),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        children: [
          if (_activeMedications.isNotEmpty) ...[
             Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Active Treatments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ),
            ..._activeMedications.map((medication) {
              return ActiveMedicationCard(
                medication: medication,
                logService: _logService,
                onEdit: () => _navigateAndRefresh(
                  EditMedicationScreen(medication: medication),
                ),
                onEnd: () => _stopTreatment(medication),
                onDelete: () async {
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
                onHistory: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicationHistoryScreen(medicationName: medication.name),
                    ),
                  );
                },
                onLogIntake: (timeStr, notes) => _logIntake(medication, timeStr, notes),
              );
            }),
          ],

          if (_activeMedications.isEmpty && _inactiveMedications.isEmpty)
             const Padding(
               padding: EdgeInsets.only(top: 50.0),
               child: Center(
                child: Text(
                  'No medications found for this profile.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
               ),
             ),

          if (_inactiveMedications.isNotEmpty) ...[
             Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Text("Past Treatments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
            ),
            ..._inactiveMedications.map((medication) {
              return InactiveMedicationCard(
                medication: medication,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicationHistoryScreen(medicationName: medication.name),
                    ),
                  );
                },
                onArchive: () async {
                   await _storageService.archiveMedication(medication, archive: true);
                   _loadMedications();
                },
                onRestore: () => _restoreTreatment(medication),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete History?'),
                      content: const Text('Remove this medication record? Logs will remain in Intake History.'),
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
              );
            }),
             const SizedBox(height: 80), 
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(const AddMedicationScreen()),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
