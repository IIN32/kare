import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  
  final _notesController = TextEditingController();
  final _totalQuantityController = TextEditingController();
  final _refillThresholdController = TextEditingController();
  
  final List<TimeOfDay> _selectedTimes = [];
  
  bool _isOngoing = true;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  final List<TextEditingController> _nagControllers = [
    TextEditingController(text: '5'),
    TextEditingController(text: '10'),
    TextEditingController(text: '15'),
  ];
  
  String _selectedType = 'pill';
  String _selectedUrgency = 'Normal';

  final List<Map<String, dynamic>> _medTypes = [
    {'id': 'pill', 'label': 'Pill', 'icon': Icons.circle},
    {'id': 'liquid', 'label': 'Liquid', 'icon': Icons.water_drop},
    {'id': 'injection', 'label': 'Injection', 'icon': Icons.vaccines},
    {'id': 'inhaler', 'label': 'Inhaler', 'icon': Icons.air},
    {'id': 'other', 'label': 'Other', 'icon': Icons.medication},
  ];

  final ProfileService _profileService = ProfileService();

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _totalQuantityController.dispose();
    _refillThresholdController.dispose();
    for (var controller in _nagControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _addTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    
    if (picked != null && mounted) {
      if (!_selectedTimes.any((t) => t.hour == picked.hour && t.minute == picked.minute)) {
        setState(() {
          _selectedTimes.add(picked);
          _selectedTimes.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        });
      }
    }
  }

  void _removeTime(TimeOfDay time) {
    setState(() {
      _selectedTimes.remove(time);
    });
  }

  Future<void> _pickDateAndTime(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : (_endDate ?? DateTime.now().add(const Duration(days: 7)));
    final firstDate = isStart ? DateTime.now().subtract(const Duration(days: 365)) : _startDate;
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null || !mounted) return;

    final DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startDate = finalDateTime;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null; 
        }
      } else {
        _endDate = finalDateTime;
      }
    });
  }

  Future<void> _saveMedication() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTimes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one reminder time')),
        );
        return;
      }

      if (!_isOngoing && _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an end date')),
        );
        return;
      }
      
      final List<int> nagIntervals = [];
      for (var controller in _nagControllers) {
        if (controller.text.isNotEmpty) {
          final int? interval = int.tryParse(controller.text);
          if (interval == null || interval <= 0 || interval > 15) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nag intervals must be between 1 and 15 minutes.')),
            );
            return;
          }
          nagIntervals.add(interval);
        }
      }

      final List<String> timeStrings = _selectedTimes.map((t) => 
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
      ).toList();
      
      final int? qty = int.tryParse(_totalQuantityController.text);
      final int? threshold = int.tryParse(_refillThresholdController.text);

      final newMedication = Medication(
        name: _nameController.text,
        dosage: _dosageController.text,
        times: timeStrings,
        frequency: 1, 
        startDate: _startDate,
        endDate: _isOngoing ? null : _endDate,
        nagIntervals: nagIntervals,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        totalQuantity: qty,
        currentQuantity: qty,
        refillThreshold: threshold,
        type: _selectedType,
        profileId: _profileService.currentProfileId,
        urgency: _selectedUrgency,
      );

      await LocalStorageService().addMedication(newMedication);

      final notificationService = NotificationService();
      
      String bodyText = 'Take ${newMedication.dosage}';
      if (newMedication.notes != null && newMedication.notes!.isNotEmpty) {
        bodyText += '\nNote: ${newMedication.notes}';
      }

      for (var time in _selectedTimes) {
        final now = DateTime.now();
        final scheduledDateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
        final String timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final String uniqueKey = '${newMedication.name}_$timeStr';
        final int baseId = uniqueKey.hashCode.abs();

        await notificationService.scheduleNotification(
          id: baseId,
          title: 'Time for ${newMedication.name}',
          body: bodyText,
          scheduledTime: scheduledDateTime,
          medicationName: newMedication.name,
          scheduledTimeStr: timeStr,
          urgency: newMedication.urgency,
        );
        
        // Schedule Nags
        for (int i = 0; i < newMedication.nagIntervals.length; i++) {
          final nagDelay = newMedication.nagIntervals[i];
          if (nagDelay > 0) {
            final nagDateTime = scheduledDateTime.add(Duration(minutes: nagDelay));
            await notificationService.scheduleNotification(
              id: baseId + i + 1,
              title: 'Reminder: ${newMedication.name}',
              body: 'Did you take your ${newMedication.dosage}?',
              scheduledTime: nagDateTime,
              medicationName: newMedication.name,
              scheduledTimeStr: timeStr,
              urgency: newMedication.urgency,
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true); 
      }
    }
  }

  Widget _buildDurationInfo() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);

    String text;
    if (_isOngoing) {
      final diff = today.difference(start).inDays;
      if (diff > 0) {
        text = 'Has been going on for $diff days';
      } else if (diff == 0) {
        text = 'Starts today';
      } else {
        text = 'Starts in ${-diff} days';
      }
    } else {
      if (_endDate == null) return const SizedBox.shrink();
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      final total = end.difference(start).inDays + 1;
      
      final elapsed = today.difference(start).inDays;
      if (elapsed > 0) {
        text = 'Active for $elapsed days (Total: $total days)';
      } else {
        text = 'Total Duration: $total days';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(200), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Medication Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _medTypes.map((type) {
              final isSelected = _selectedType == type['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(type['label']),
                  avatar: Icon(type['icon'], size: 18, color: isSelected ? Colors.white : Colors.grey),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.secondary,
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedType = type['id'];
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildUrgencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Urgency Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          style: SegmentedButton.styleFrom(
            foregroundColor: Colors.grey,
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: Theme.of(context).colorScheme.primary,
          ),
          segments: const [
            ButtonSegment<String>(value: 'Normal', label: Text('Normal'), icon: Icon(Icons.notifications, color: Colors.blue)),
            ButtonSegment<String>(value: 'Medium', label: Text('Medium'), icon: Icon(Icons.notifications_active, color: Colors.orange)),
            ButtonSegment<String>(value: 'High', label: Text('High'), icon: Icon(Icons.error, color: Colors.red)),
          ],
          selected: {_selectedUrgency},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _selectedUrgency = newSelection.first;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medication'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage (e.g., 500mg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vaccines),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a dosage' : null,
              ),
              const SizedBox(height: 24),
              
              _buildUrgencySelector(),
              const SizedBox(height: 24),

              _buildTypeSelector(),
              const SizedBox(height: 24),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Instructions (Optional)',
                  hintText: 'e.g., Take with food',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // REFILL SECTION
              const Text('Refill Tracking (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current Quantity',
                        border: OutlineInputBorder(),
                        suffixText: 'units',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _refillThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Alert Threshold',
                        border: OutlineInputBorder(),
                        suffixText: 'units',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // DATES SECTION
              const Text('Treatment Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              ListTile(
                title: const Text('Start Date & Time'),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDateAndTime(context, true),
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                title: const Text('Ongoing Treatment'),
                value: _isOngoing,
                onChanged: (bool value) {
                  setState(() {
                    _isOngoing = value;
                    if (value) _endDate = null;
                  });
                },
              ),

              if (!_isOngoing)
                ListTile(
                  title: const Text('End Date & Time'),
                  subtitle: Text(_endDate == null ? 'Select Date & Time' : DateFormat.yMMMd().add_jm().format(_endDate!)),
                  trailing: const Icon(Icons.event_busy),
                  onTap: () => _pickDateAndTime(context, false),
                ),
                
              _buildDurationInfo(),

              const SizedBox(height: 24),

              // DAILY REMINDER TIMES
              const Text('Daily Reminder Times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, 
                runSpacing: 8,
                children: [
                  ..._selectedTimes.map((t) => Chip(
                    label: Text(t.format(context)),
                    onDeleted: () => _removeTime(t),
                  )),
                  ActionChip(
                    avatar: const Icon(Icons.add),
                    label: const Text('Add Time'),
                    onPressed: () => _addTime(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // NAG REMINDERS SECTION
              const Text('Follow-up Reminders (minutes after)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 2 ? 8.0 : 0),
                      child: TextFormField(
                        controller: _nagControllers[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nag ${index + 1}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saveMedication,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Medication'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
