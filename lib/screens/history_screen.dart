import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../models/intake_log.dart';
import '../services/local_storage_service.dart';
import '../services/log_service.dart';

// Define the enum so it can be used by other screens
enum HistoryPeriod { week, month, year, all }

class HistoryScreen extends StatefulWidget {
  final HistoryPeriod initialPeriod;

  const HistoryScreen({
    super.key,
    this.initialPeriod = HistoryPeriod.all,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final LocalStorageService _storageService = LocalStorageService();
  final LogService _logService = LogService();
  
  late HistoryPeriod _currentPeriod;
  Map<DateTime, List<IntakeLog>> _groupedLogs = {};

  @override
  void initState() {
    super.initState();
    _currentPeriod = widget.initialPeriod;
    _loadData();
  }

  void _loadData() {
    setState(() {
      var allLogs = _logService.getLogs();
      
      // Filter logs based on the selected period
      final now = DateTime.now();
      DateTime? cutoff;
      
      switch (_currentPeriod) {
        case HistoryPeriod.week:
          cutoff = now.subtract(Duration(days: now.weekday - 1));
          cutoff = DateTime(cutoff.year, cutoff.month, cutoff.day);
          break;
        case HistoryPeriod.month:
          cutoff = DateTime(now.year, now.month, 1);
          break;
        case HistoryPeriod.year:
          cutoff = DateTime(now.year, 1, 1);
          break;
        case HistoryPeriod.all:
          cutoff = null; // No cutoff for all time
          break;
      }

      if (cutoff != null) {
        allLogs = allLogs.where((log) => !log.timestamp.isBefore(cutoff!)).toList();
      }

      _groupedLogs = groupBy(allLogs, (log) => DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day));
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Intake Logs?'),
        content: const Text('This will delete all intake records. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _logService.clearAll();
      _loadData();
    }
  }

  Future<void> _confirmDeleteMedicationDay(String medName, DateTime day) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $medName Logs?'),
        content: Text('Delete all logs for $medName on ${DateFormat.yMMMd().format(day)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _logService.deleteLogsForMedicationOnDay(medName, day);
      _loadData();
    }
  }

  void _showIntakeDetails(IntakeLog log) {
    final scheduledParts = log.scheduledTime!.split(':');
    final scheduledHour = int.parse(scheduledParts[0]);
    final scheduledMinute = int.parse(scheduledParts[1]);
    final scheduledDateTime = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day, scheduledHour, scheduledMinute);

    final difference = log.timestamp.difference(scheduledDateTime);
    String latenessMessage = "Taken on time.";

    if (difference.inMinutes > 0) {
      latenessMessage = "Taken ${difference.inMinutes} minutes late.";
    } else if (difference.inMinutes < 0) {
      latenessMessage = "Taken ${-difference.inMinutes} minutes early.";
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Intake Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Scheduled for: ${DateFormat.jm().format(scheduledDateTime)}"),
            Text("Taken at: ${DateFormat.jm().format(log.timestamp)}"),
            const SizedBox(height: 16),
            Text(latenessMessage, style: TextStyle(fontWeight: FontWeight.bold, color: difference.inMinutes > 0 ? Colors.orange : Colors.green)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Widget _buildDailyStatus(String medName, List<IntakeLog> dailyLogs, DateTime day) {
    final medication = _storageService.getMedications().firstWhereOrNull((m) => m.name == medName);
    if (medication == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 4.0,
      runSpacing: 0.0,
      children: medication.times.map((timeStr) {
        final logForSlot = dailyLogs.firstWhereOrNull((log) => log.scheduledTime == timeStr);
        final bool isTaken = logForSlot != null;
        
        final parts = timeStr.split(':');
        final scheduledH = int.parse(parts[0]);
        final scheduledM = int.parse(parts[1]);
        String formattedTime = DateFormat.j().format(DateTime(2023, 1, 1, scheduledH, scheduledM)).toLowerCase();

        bool isMissed = false;
        if (!isTaken) {
            final scheduledDateTime = DateTime(day.year, day.month, day.day, scheduledH, scheduledM);
            if (DateTime.now().isAfter(scheduledDateTime.add(const Duration(minutes: 16)))) {
                isMissed = true;
            }
        }

        return InkWell(
          onTap: isTaken ? () => _showIntakeDetails(logForSlot) : null,
          child: Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              isTaken ? Icons.check_circle : (isMissed ? Icons.cancel : Icons.radio_button_unchecked),
              color: isTaken ? Colors.white : (isMissed ? Colors.white : Colors.grey[400]),
              size: 16,
            ),
            label: Text(formattedTime, style: TextStyle(color: isTaken ? Colors.white : (isMissed ? Colors.white : Colors.black), fontSize: 12)),
            backgroundColor: isTaken ? Colors.green : (isMissed ? Colors.red : Colors.grey[100]),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedDays = _groupedLogs.keys.sorted((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intake History'),
        actions: [
          PopupMenuButton<HistoryPeriod>(
            initialValue: _currentPeriod,
            icon: const Icon(Icons.filter_list),
            onSelected: (HistoryPeriod item) {
              setState(() {
                _currentPeriod = item;
                _loadData();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<HistoryPeriod>>[
              const PopupMenuItem<HistoryPeriod>(value: HistoryPeriod.week, child: Text('This Week')),
              const PopupMenuItem<HistoryPeriod>(value: HistoryPeriod.month, child: Text('This Month')),
              const PopupMenuItem<HistoryPeriod>(value: HistoryPeriod.year, child: Text('This Year')),
              const PopupMenuItem<HistoryPeriod>(value: HistoryPeriod.all, child: Text('All Time')),
            ],
          ),
          IconButton(
             icon: const Icon(Icons.delete_forever),
             onPressed: _clearHistory,
             tooltip: 'Clear Intake Logs',
           ),
        ],
      ),
      body: _groupedLogs.isEmpty
          ? Center(
              child: Text(
                'No logs found for ${_currentPeriod.name == 'all' ? 'all time' : 'this ${_currentPeriod.name}'}.', 
                style: const TextStyle(color: Colors.grey)
              )
            )
          : ListView.builder(
              itemCount: sortedDays.length,
              itemBuilder: (context, index) {
                final day = sortedDays[index];
                final logsForDay = _groupedLogs[day]!;
                
                final medsOnDay = groupBy(logsForDay, (log) => log.medicationName);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMEd().format(day),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      ...medsOnDay.entries.map((entry) {
                        final medName = entry.key;
                        final dailyLogs = entry.value;
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(medName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                      onPressed: () => _confirmDeleteMedicationDay(medName, day),
                                      tooltip: 'Delete all for this day',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildDailyStatus(medName, dailyLogs, day),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
