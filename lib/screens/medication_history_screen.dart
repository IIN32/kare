import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../services/log_service.dart';
import '../models/intake_log.dart';

class MedicationHistoryScreen extends StatefulWidget {
  final String medicationName;

  const MedicationHistoryScreen({super.key, required this.medicationName});

  @override
  State<MedicationHistoryScreen> createState() => _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  final LogService _logService = LogService();
  Map<DateTime, List<IntakeLog>> _groupedLogs = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      final allLogs = _logService.getLogsForMedication(widget.medicationName);
      // Group by day
      _groupedLogs = groupBy(allLogs, (log) => DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedDays = _groupedLogs.keys.sorted((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.medicationName} History'),
      ),
      body: _groupedLogs.isEmpty
          ? const Center(child: Text('No history found for this medication.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: sortedDays.length,
              itemBuilder: (context, index) {
                final day = sortedDays[index];
                final dailyLogs = _groupedLogs[day]!;
                
                // Sort logs by scheduled time (if possible) or timestamp
                dailyLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMEd().format(day),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 4),
                      Card(
                        child: Column(
                          children: dailyLogs.map((log) {
                            final scheduledParts = log.scheduledTime!.split(':');
                            final scheduledTime = TimeOfDay(hour: int.parse(scheduledParts[0]), minute: int.parse(scheduledParts[1]));
                            final takenTime = TimeOfDay.fromDateTime(log.timestamp);
                            
                            return ListTile(
                              leading: const Icon(Icons.check_circle, color: Colors.green),
                              title: Text('Scheduled: ${scheduledTime.format(context)}'),
                              subtitle: Text('Taken at: ${takenTime.format(context)}'),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
