import 'package:flutter/material.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/log_service.dart';
import 'services/profile_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/setup_screen.dart';

// Global instances
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final AuthService authService = AuthService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Services
  await LocalStorageService().init();
  await LogService().init();
  await ProfileService().init();
  await NotificationService().init();

  // Load Theme
  final isDark = LocalStorageService().isDarkMode;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final localStorage = LocalStorageService();
    final profileService = ProfileService();
    final bool isFirstLaunch = profileService.getProfiles().isEmpty;
    
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Kare',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue.shade700,
              brightness: Brightness.light,
              primary: Colors.blue.shade700,
              secondary: Colors.cyan.shade400,
            ),
            scaffoldBackgroundColor: Colors.grey.shade100,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue.shade700,
              brightness: Brightness.dark,
              primary: Colors.blue.shade300,
              secondary: Colors.cyan.shade400,
            ),
            scaffoldBackgroundColor: Colors.grey.shade900,
            useMaterial3: true,
          ),
          themeMode: currentMode,
          home: isFirstLaunch
              ? const SetupScreen()
              : ListenableBuilder(
                  listenable: authService,
                  builder: (context, child) {
                    final bool pinIsSet = localStorage.getPin() != null;
                    if (pinIsSet && authService.isLocked) {
                      return const PinScreen();
                    }
                    return const HomeScreen();
                  },
                ),
        );
      },
    );
  }
}
