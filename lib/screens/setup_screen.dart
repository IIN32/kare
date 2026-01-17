import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../models/profile.dart';
import 'pin_screen.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _pageController = PageController();
  final _profileNameController = TextEditingController(text: 'Me');
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _profileNameController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (_profileNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the first profile.')),
      );
      return;
    }

    if (mounted) {
      final pinWasSet = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinScreen(isSettingPin: true)),
      );

      if (pinWasSet == true && mounted) {
        final profileService = ProfileService();
        final defaultProfile = Profile(
          id: 'default', 
          name: _profileNameController.text,
        );
        
        await profileService.addProfile(defaultProfile);
        await profileService.setCurrentProfile(defaultProfile.id);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  Widget _buildPage({required String title, required String description, required IconData icon, Widget? extraContent}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 48),
          Text(title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(description, style: const TextStyle(fontSize: 16, height: 1.5), textAlign: TextAlign.center),
          if (extraContent != null) ...[
            const SizedBox(height: 48),
            extraContent,
          ],
        ],
      ),
    );
  }
  
  Widget _buildFinalPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle_rounded, size: 100, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 48),
            Text('Let\'s Get Started', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text('Create your profile to begin.', style: TextStyle(fontSize: 16, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 48),
            TextField(
              controller: _profileNameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _completeSetup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Profile & Set PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildPage(
                title: 'Welcome to Kare',
                description: 'Your personal companion for managing medications and tracking your health journey.',
                icon: Icons.health_and_safety_rounded,
              ),
              _buildPage(
                title: 'Never Miss a Dose',
                description: 'Set reminders for your medications and track your adherence progress every day.',
                icon: Icons.notifications_active_rounded,
              ),
              _buildPage(
                title: 'Secure & Private',
                description: 'Your health data is stored locally and protected by a secure PIN.',
                icon: Icons.lock_rounded,
              ),
              _buildFinalPage(),
            ],
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ),
          if (_currentPage < 3)
            Positioned(
              bottom: 24,
              right: 24,
              child: TextButton(
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Next'),
              ),
            ),
        ],
      ),
    );
  }
}
