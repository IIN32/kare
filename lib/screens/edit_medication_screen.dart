import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class EditMedicationScreen extends StatefulWidget {
  final Medication medication;
  final int index;

  const EditMedicationScreen({
    super.key,
    required this.medication,
    required this.index,
  });

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  
  late List<TimeOfDay> _selectedTimes;
  late bool _isOngoing;
  late DateTime _startDate;
  late DateTime? _endDate;

  // Nag Interval Controllers
  late List<TextEditingController> _nagControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication.name);
    _dosageController = TextEditingController(text: widget.medication.dosage);
    
    _selectedTimes = widget.medication.times.map((tString) {
      final parts = tString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();

    _startDate = widget.medication.startDate;
    _endDate = widget.medication.endDate;
    _isOngoing = _endDate == null;

    // Initialize nag controllers with existing or default values
    _nagControllers = List.generate(3, (index) {
      if (index < widget.medication.nagIntervals.length) {
        return TextEditingController(text: widget.medication.nagIntervals[index].toString());
      } else {
        return TextEditingController(); // Empty for non-existent ones
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    for (var controller in _nagControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ... (addTime, removeTime, pickDateAndTime methods are the same) ...
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

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
       if (_selectedTimes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one reminder time')),
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

      final notificationService = NotificationService();
      
      for (var timeString in widget.medication.times) {
        final String uniqueKey = '${widget.medication.name}_$timeString';
        final int baseId = uniqueKey.hashCode.abs();

        await notificationService.cancelNotification(baseId); 
        for (int i = 1; i <= widget.medication.nagIntervals.length; i++) {
          await notificationService.cancelNotification(baseId + i); 
        }
      }

      final List<String> timeStrings = _selectedTimes.map((t) => 
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
      ).toList();
      
      final updatedMedication = Medication(
        name: _nameController.text,
        dosage: _dosageController.text,
        times: timeStrings,
        frequency: widget.medication.frequency,
        startDate: _startDate,
        endDate: _isOngoing ? null : _endDate,
        nagIntervals: nagIntervals,
      );

      await LocalStorageService().updateMedication(widget.medication, updatedMedication);

      for (var time in _selectedTimes) {
        // Fix inconsistent ID generation
        final String hour = time.hour.toString().padLeft(2, '0');
        final String minute = time.minute.toString().padLeft(2, '0');
        final String uniqueKey = '${updatedMedication.name}_$hour:$minute';
        final int baseId = uniqueKey.hashCode.abs();

        await notificationService.scheduleNotification(
          id: baseId,
          title: 'Time for ${_nameController.text}',
          body: 'Take ${_dosageController.text}',
          hour: time.hour,
          minute: time.minute,
        );

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
            id: baseId + i + 1,
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
        title: const Text('Edit Medication'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Medication Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(labelText: 'Dosage', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),

              const Text('Treatment Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ListTile(
                title: const Text('Start Date & Time'),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(_startDate)),
                onTap: () => _pickDateAndTime(context, true),
              ),
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
                  onTap: () => _pickDateAndTime(context, false),
                ),

              const SizedBox(height: 24),

              const Text('Daily Reminder Times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Wrap(
                spacing: 8, 
                runSpacing: 8,
                children: [
                  ..._selectedTimes.map((t) => Chip(
                    label: Text(t.format(context)),
                    onDeleted: () => _removeTime(t),
                  )),
                  ActionChip(avatar: const Icon(Icons.add), label: const Text('Add Time'), onPressed: () => _addTime(context)),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Follow-up Reminders (minutes after)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 2 ? 8.0 : 0),
                      child: TextFormField(
                        controller: _nagControllers[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Nag ${index + 1}'),
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 32),

              ElevatedButton(onPressed: _saveChanges, child: const Text('Save Changes')),
            ],
          ),
        ),
      ),
    );
  }
}
