import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../services/log_service.dart';

class ActiveMedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onEnd;
  final VoidCallback onDelete;
  final VoidCallback onHistory;
  final Function(String) onLogIntake;
  final LogService logService; // Passed to avoid re-instantiating if possible, or we can instantiate inside

  const ActiveMedicationCard({
    super.key,
    required this.medication,
    required this.onEdit,
    required this.onEnd,
    required this.onDelete,
    required this.onHistory,
    required this.onLogIntake,
    required this.logService,
  });

  String _getDurationString(Medication medication) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(medication.startDate.year, medication.startDate.month, medication.startDate.day);
    
    final diffDays = today.difference(start).inDays;
    
    if (diffDays == 0) {
      return 'Started today';
    } else if (diffDays > 0) {
      return 'Active for $diffDays days';
    } else {
      return 'Starts in ${-diffDays} days';
    }
  }

  Widget _buildTimeSlots(BuildContext context) {
    return Wrap(
      spacing: 4.0, 
      runSpacing: 0.0,
      children: medication.times.map((timeStr) {
        final todayLogs = logService.getLogsForMedication(medication.name).where((log) {
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
              
              String statusText = "Taken";
              if (log.status == 'taken_on_time') statusText = "Taken On Time";
              else if (log.status == 'taken_late') statusText = "Taken Late";

              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Slot Taken at $formattedTime'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text('Status: $statusText', style: TextStyle(fontWeight: FontWeight.bold, color: log.status == 'taken_late' ? Colors.red : Colors.green)),
                        const SizedBox(height: 4),
                        Text('Taken at: $timeTaken'),
                    ]
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
            } else if (isFuture) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('It is not time for this dose yet.')),
              );
            } else {
              onLogIntake(timeStr);
            }
          },
          child: Chip(
            visualDensity: VisualDensity.compact,
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
    final String startStr = DateFormat.MMMd().format(medication.startDate);
    final String endStr = medication.endDate != null 
        ? DateFormat.MMMd().format(medication.endDate!) 
        : 'Ongoing';
    final String durationStr = _getDurationString(medication);
    
    Color urgencyColor;
    switch (medication.urgency) {
      case 'High':
        urgencyColor = Colors.red;
        break;
      case 'Medium':
        urgencyColor = Colors.orange;
        break;
      default:
        urgencyColor = Colors.blue;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: urgencyColor, width: 2),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: urgencyColor,
          child: const Icon(Icons.medication_liquid, color: Colors.white),
        ),
        title: Text(medication.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dosage: ${medication.dosage}'),
            Text(durationStr, style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildTimeSlots(context),
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
                icon: const Icon(Icons.history, color: Colors.purple),
                label: const Text('History'),
                onPressed: onHistory,
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit, color: Colors.blueGrey),
                label: const Text('Edit'),
                onPressed: onEdit,
              ),
              TextButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.orange),
                label: const Text('End'),
                onPressed: onEnd,
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              label: const Text('Delete Forever'),
              onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class InactiveMedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onArchive; 
  final VoidCallback onRestore; 

  const InactiveMedicationCard({
    super.key,
    required this.medication,
    required this.onTap,
    required this.onDelete,
    required this.onArchive, 
    required this.onRestore, 
  });

  @override
  Widget build(BuildContext context) {
    final String startStr = DateFormat.yMMMd().format(medication.startDate);
    final String endStr = DateFormat.yMMMd().format(medication.endDate!); 

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.history, color: Colors.white),
            ),
            title: Text(medication.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('Dosage: ${medication.dosage}'),
                 const SizedBox(height: 4),
                 Text('Started: $startStr', style: const TextStyle(fontSize: 12)),
                 Text('Ended: $endStr', style: const TextStyle(fontSize: 12)),
                 const SizedBox(height: 4),
                 const Text('Tap to view history', style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'restore', child: Text('Restore Treatment')),
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
                const PopupMenuItem(value: 'delete', child: Text('Delete Forever')),
              ],
              onSelected: (value) {
                if (value == 'restore') {
                  onRestore();
                } else if (value == 'archive') {
                  onArchive();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
