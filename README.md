# Kare - Medication Reminder App

A simple, yet powerful medication reminder and tracking application built with Flutter. This app helps users manage their medication schedules, track their intake history, and stay on top of their health regimen.

## ✨ Features

- **Flexible Scheduling:** Add medications with multiple daily reminder times.
- **Customizable Reminders:** Set custom follow-up "nag" reminders to ensure you never miss a dose.
- **Smart Tracking:** A daily checklist to mark doses as Taken, Missed, or Pending.
- **Treatment Duration:** Set a start and end date for your treatment, or mark it as ongoing.
- **Intake History:** A clear, grouped view of your past intake history, showing what you took and when.
- **Active & Past Treatments:** Medications automatically move from the active list to a historical archive when the treatment period ends.
- **Local Notifications:** All reminders are scheduled locally on your device and work offline.
- **Persistent Storage:** Your data is saved securely on your device using Hive.

## 🚀 Getting Started

This project is a starting point for a Flutter application.

To get a local copy up and running, follow these simple steps.

### Prerequisites

- Flutter SDK: [Installation Guide](https://flutter.dev/docs/get-started/install)
- An editor like VS Code or Android Studio

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/your_username/your_repository.git
   ```
2. Navigate to the project directory
   ```sh
   cd kare
   ```
3. Install packages
   ```sh
   flutter pub get
   ```
4. Run the build runner to generate Hive adapters
   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run the app
   ```sh
   flutter run
   ```

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/your_username/your_repository/issues).

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
