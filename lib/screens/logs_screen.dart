import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/intake_log.dart';
import '../services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final LogService _logService = LogService();
  List<IntakeLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _logs = _logService.getLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intake History'),
      ),
      body: _logs.isEmpty
          ? const Center(
              child: Text(
                'No history yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];

                // Formatted date and time
                final String date = DateFormat.yMMMd().format(log.timestamp);
                final String time = DateFormat.jm().format(log.timestamp);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: log.status == 'taken' ? Colors.green : Colors.orange,
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                    title: Text(log.medicationName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Status: ${log.status.toUpperCase()}'),
                    trailing: Text('$date\n$time', textAlign: TextAlign.right),
                  ),
                );
              },
            ),
    );
  }
}
