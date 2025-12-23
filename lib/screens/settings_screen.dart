import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/local_storage_service.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../models/profile.dart';
import '../models/medication.dart';
import '../main.dart'; // To access themeNotifier
import 'pin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileService _profileService = ProfileService();
  final LocalStorageService _storageService = LocalStorageService();
  List<Profile> _profiles = [];
  List<Medication> _archivedMedications = [];
  final _newProfileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profileService.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    _profileService.removeListener(_loadData);
    _newProfileController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _profiles = _profileService.getProfiles();
      _archivedMedications = _storageService.getMedications().where((med) => med.isArchived).toList();
    });
  }

  Future<void> _clearAllData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App Data?'),
        content: const Text(
            'This will delete all medications, history logs, and settings. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset Everything',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await LocalStorageService().clearAll();
      await LogService().clearAll();
      await NotificationService().notificationsPlugin.cancelAll();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset.')),
        );
      }
    }
  }

  void _addNewProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Profile'),
        content: TextField(
          controller: _newProfileController,
          decoration: const InputDecoration(hintText: 'Profile Name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Next: Set PIN'),
            onPressed: () async {
              if (_newProfileController.text.isNotEmpty) {
                final profileName = _newProfileController.text;
                Navigator.pop(context); // Close dialog
                _newProfileController.clear();

                // Navigate to PinScreen
                final newPin = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const PinScreen(isSettingPin: true)),
                );

                if (newPin != null && newPin.isNotEmpty) {
                  final newProfile = Profile(
                    id: DateTime.now().toIso8601String(),
                    name: profileName,
                    pin: newPin,
                  );
                  await _profileService.addProfile(newProfile);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfile(String profileId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: const Text('This will delete the profile and all its associated medications. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _profileService.deleteProfile(profileId);
    }
  }

  void _managePin() {
    final hasPin = _storageService.getPin() != null;
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: Text(hasPin ? 'Change Master PIN' : 'Set Master PIN'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PinScreen(isSettingPin: true)));
              setState(() {}); // Re-build to update UI
            },
          ),
          if (hasPin)
            ListTile(
              leading: const Icon(Icons.lock_open, color: Colors.red),
              title: const Text('Remove Master PIN', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await _storageService.setPin(null);
                Navigator.pop(context);
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Manually formatting date to avoid DateFormat issues
    // final DateFormat formatter = DateFormat.yMMMd(); // Removed for now
    final bool hasPin = _storageService.getPin() != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          SwitchListTile(
            title: const Text('Require Master PIN to open app'),
            value: hasPin,
            onChanged: (value) {
              _managePin();
            },
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, _) {
              final isDark = currentMode == ThemeMode.dark;
              return SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Reduce eye strain'),
                value: isDark,
                onChanged: (value) {
                  final newMode = value ? ThemeMode.dark : ThemeMode.light;
                  themeNotifier.value = newMode;
                  LocalStorageService().setDarkMode(value);
                },
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              );
            },
          ),
          const Divider(),
           const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Profiles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ..._profiles.map((profile) {
            final bool isSelected = _profileService.currentProfileId == profile.id;
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(profile.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(Icons.check_circle, color: Colors.green),
                    ),
                  if (profile.id != 'default')
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteProfile(profile.id),
                    ),
                ],
              ),
              onTap: () {
                _profileService.setCurrentProfile(profile.id);
              },
            );
          }),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add Profile'),
            onTap: _addNewProfile,
          ),
          const Divider(),
          ExpansionTile(
            title: const Text('Archived Medications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            children: _archivedMedications.isEmpty
              ? [const ListTile(title: Text('No archived medications.'))]
              : _archivedMedications.map((med) => ListTile(
                  title: Text(med.name),
                  subtitle: Text('Archived on ${med.endDate!.year}-${med.endDate!.month}-${med.endDate!.day}'),
                  trailing: TextButton(
                    child: const Text('Unarchive'),
                    onPressed: () async {
                      await _storageService.archiveMedication(med, archive: false);
                      _loadData();
                    },
                  ),
                )).toList(),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete medications and history'),
            onTap: () => _clearAllData(context),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
