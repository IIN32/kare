import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class EditMedicationScreen extends StatefulWidget {
  final Medication medication;

  const EditMedicationScreen({
    super.key,
    required this.medication,
  });

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  
  late TextEditingController _notesController;
  late TextEditingController _totalQuantityController;
  late TextEditingController _currentQuantityController;
  late TextEditingController _refillThresholdController;
  
  late List<TimeOfDay> _selectedTimes;
  late bool _isOngoing;
  late DateTime _startDate;
  late DateTime? _endDate;
  
  String _selectedType = 'pill';
  String _selectedUrgency = 'Normal';

  final List<Map<String, dynamic>> _medTypes = [
    {'id': 'pill', 'label': 'Pill', 'icon': Icons.circle},
    {'id': 'liquid', 'label': 'Liquid', 'icon': Icons.water_drop},
    {'id': 'injection', 'label': 'Injection', 'icon': Icons.vaccines},
    {'id': 'inhaler', 'label': 'Inhaler', 'icon': Icons.air},
    {'id': 'other', 'label': 'Other', 'icon': Icons.medication},
  ];

  late List<TextEditingController> _nagControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication.name);
    _dosageController = TextEditingController(text: widget.medication.dosage);
    _notesController = TextEditingController(text: widget.medication.notes ?? '');
    _totalQuantityController = TextEditingController(text: widget.medication.totalQuantity?.toString() ?? '');
    _currentQuantityController = TextEditingController(text: widget.medication.currentQuantity?.toString() ?? '');
    _refillThresholdController = TextEditingController(text: widget.medication.refillThreshold?.toString() ?? '');
    _selectedType = widget.medication.type ?? 'pill';
    _selectedUrgency = widget.medication.urgency;
    
    _selectedTimes = widget.medication.times.map((tString) {
      final parts = tString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();

    _startDate = widget.medication.startDate;
    _endDate = widget.medication.endDate;
    _isOngoing = _endDate == null;

    _nagControllers = List.generate(3, (index) {
      if (index < widget.medication.nagIntervals.length) {
        return TextEditingController(text: widget.medication.nagIntervals[index].toString());
      } else {
        return TextEditingController(); 
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _totalQuantityController.dispose();
    _currentQuantityController.dispose();
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
          segments: const [
            ButtonSegment<String>(value: 'Normal', label: Text('Normal'), icon: Icon(Icons.notifications)),
            ButtonSegment<String>(value: 'Medium', label: Text('Medium'), icon: Icon(Icons.notifications_active)),
            ButtonSegment<String>(value: 'High', label: Text('High'), icon: Icon(Icons.error)),
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
      
      // Cancel all old notifications before rescheduling
      for (var timeString in widget.medication.times) {
        final String uniqueKey = '${widget.medication.name}_$timeString';
        final int baseId = uniqueKey.hashCode.abs();

        await notificationService.cancelNotification(baseId); 
        for (int i = 1; i <= 15; i++) {
          await notificationService.cancelNotification(baseId + i); 
        }
      }

      final List<String> timeStrings = _selectedTimes.map((t) => 
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
      ).toList();
      
      final int? totalQty = int.tryParse(_totalQuantityController.text);
      final int? currentQty = int.tryParse(_currentQuantityController.text);
      final int? threshold = int.tryParse(_refillThresholdController.text);

      final updatedMedication = Medication(
        name: _nameController.text,
        dosage: _dosageController.text,
        times: timeStrings,
        frequency: widget.medication.frequency,
        startDate: _startDate,
        endDate: _isOngoing ? null : _endDate,
        nagIntervals: nagIntervals,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        totalQuantity: totalQty,
        currentQuantity: currentQty,
        refillThreshold: threshold,
        type: _selectedType,
        profileId: widget.medication.profileId,
        urgency: _selectedUrgency,
      );
      
      await LocalStorageService().updateMedication(widget.medication, updatedMedication);
      
      String bodyText = 'Take ${updatedMedication.dosage}';
      if (updatedMedication.notes != null && updatedMedication.notes!.isNotEmpty) {
        bodyText += '\nNote: ${updatedMedication.notes}';
      }

      // Re-schedule notifications
      for (var time in _selectedTimes) {
        final now = DateTime.now();
        final scheduledDateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
        final String timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final String uniqueKey = '${updatedMedication.name}_$timeStr';
        final int baseId = uniqueKey.hashCode.abs();

        await notificationService.scheduleNotification(
          id: baseId,
          title: 'Time for ${updatedMedication.name}',
          body: bodyText,
          scheduledTime: scheduledDateTime,
          medicationName: updatedMedication.name,
          scheduledTimeStr: timeStr,
          urgency: _selectedUrgency,
        );

        // Schedule Nags
        for (int i = 0; i < updatedMedication.nagIntervals.length; i++) {
          final nagDelay = updatedMedication.nagIntervals[i];
          if (nagDelay > 0) {
            final nagDateTime = scheduledDateTime.add(Duration(minutes: nagDelay));
            await notificationService.scheduleNotification(
              id: baseId + i + 1,
              title: 'Reminder: ${updatedMedication.name}',
              body: 'Did you take your ${updatedMedication.dosage}?',
              scheduledTime: nagDateTime,
              medicationName: updatedMedication.name,
              scheduledTimeStr: timeStr,
              urgency: _selectedUrgency,
            );
          }
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
              
              _buildUrgencySelector(),
              const SizedBox(height: 24),

              _buildTypeSelector(),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Instructions',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              const Text('Refill Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Package Size',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                   Expanded(
                    child: TextFormField(
                      controller: _currentQuantityController, // New
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
               TextFormField(
                controller: _refillThresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Alert Threshold',
                  border: OutlineInputBorder(),
                ),
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
