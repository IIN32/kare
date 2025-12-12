import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  
  final List<TimeOfDay> _selectedTimes = [];
  
  bool _isOngoing = true;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // Nag Interval Controllers
  final List<TextEditingController> _nagControllers = [
    TextEditingController(text: '5'),
    TextEditingController(text: '10'),
    TextEditingController(text: '15'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
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
    
    if (!mounted) return;

    if (picked != null) {
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

    if (pickedDate == null) return;
    
    if (!mounted) return;

    final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null) return;

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
      
      // Validate and collect nag intervals
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
      
      final newMedication = Medication(
        name: _nameController.text,
        dosage: _dosageController.text,
        times: timeStrings,
        frequency: 1, 
        startDate: _startDate,
        endDate: _isOngoing ? null : _endDate,
        nagIntervals: nagIntervals,
      );

      await LocalStorageService().addMedication(newMedication);

      final notificationService = NotificationService();
      
      for (var time in _selectedTimes) {
        // Ensure consistent ID generation using padded time
        final String hour = time.hour.toString().padLeft(2, '0');
        final String minute = time.minute.toString().padLeft(2, '0');
        final String uniqueKey = '${newMedication.name}_$hour:$minute';
        final int baseId = uniqueKey.hashCode.abs();

        await notificationService.scheduleNotification(
          id: baseId,
          title: 'Time for ${_nameController.text}',
          body: 'Take ${_dosageController.text}',
          hour: time.hour,
          minute: time.minute,
        );
        
        // Use custom nag intervals
        for (int i = 0; i < nagIntervals.length; i++) {
          final int nagDelayMinutes = nagIntervals[i];
          int nagHour = time.hour;
          int nagMinute = time.minute + nagDelayMinutes;
          
          while (nagMinute >= 60) {
            nagMinute -= 60;
            nagHour += 1;
          }
          if (nagHour >= 24) nagHour -= 24;

          await notificationService.scheduleNotification(
            id: baseId + i + 1, // Use a safe offset
            title: 'Missed Meds? ${_nameController.text}',
            body: 'Reminder: Take ${_dosageController.text}',
            hour: nagHour,
            minute: nagMinute,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); 
      }
    }
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
                  labelText: 'Dosage',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vaccines),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a dosage' : null,
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
