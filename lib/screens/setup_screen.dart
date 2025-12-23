import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/local_storage_service.dart';
import '../models/profile.dart';
import 'pin_screen.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _profileNameController = TextEditingController(text: 'Me');

  Future<void> _completeSetup() async {
    if (_profileNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the first profile.')),
      );
      return;
    }

    // 1. Prompt user to set the master app PIN FIRST
    if (mounted) {
      final pinWasSet = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinScreen(isSettingPin: true)),
      );

      // 2. Only if PIN was set, create the profile and proceed
      if (pinWasSet == true && mounted) {
        final profileService = ProfileService();
        final defaultProfile = Profile(
          id: 'default', 
          name: _profileNameController.text,
        );
        
        // Save profile only after PIN success
        await profileService.addProfile(defaultProfile);
        await profileService.setCurrentProfile(defaultProfile.id);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Welcome to Kare!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Let\'s get started by creating your primary profile.', textAlign: TextAlign.center),
              const SizedBox(height: 32),
              TextField(
                controller: _profileNameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _completeSetup,
                child: const Text('Next: Set App PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
