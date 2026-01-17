import 'package:hive_flutter/hive_flutter.dart';
import '../models/medication.dart';
import '../models/profile.dart'; // Import Profile model

class LocalStorageService {
  static const String _boxName = 'medicationsBox';
  static const String _settingsBoxName = 'settingsBox';

  // Initialize Hive and register adapters
  Future<void> init() async {
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(MedicationAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) { // New adapter for Profile
       Hive.registerAdapter(ProfileAdapter());
    }
    await Hive.openBox<Medication>(_boxName);
    await Hive.openBox(_settingsBoxName);
  }

  // Get the open box
  Box<Medication> get _box => Hive.box<Medication>(_boxName);
  Box get _settingsBox => Hive.box(_settingsBoxName);

  // Get all medications
  List<Medication> getMedications() {
    return _box.values.toList();
  }

  // Add a new medication
  Future<void> addMedication(Medication medication) async {
    await _box.add(medication);
  }

  // Update a medication 
  Future<void> updateMedication(Medication oldMed, Medication newMed) async {
    if (oldMed.isInBox) {
      await _box.put(oldMed.key, newMed);
    }
  }
  
  // Helper to manually stop a medication
  Future<void> stopMedication(Medication med) async {
    med.endDate = DateTime.now();
    await med.save();
  }

  Future<void> archiveMedication(Medication med, {bool archive = true}) async {
    med.isArchived = archive;
    await med.save();
  }

  Future<void> restoreMedication(Medication med) async {
    med.endDate = null;
    await med.save();
  }

  // Delete a medication
  Future<void> deleteMedication(Medication med) async {
    if (med.isInBox) {
      await med.delete();
    }
  }
  
  // Clear all data
  Future<void> clearAll() async {
    await _box.clear();
    await _settingsBox.clear();
  }

  // SETTINGS
  bool get isDarkMode => _settingsBox.get('isDarkMode', defaultValue: false);
  Future<void> setDarkMode(bool value) async {
    await _settingsBox.put('isDarkMode', value);
  }

  bool get isHighAccuracyMode => _settingsBox.get('isHighAccuracyMode', defaultValue: false);
  Future<void> setHighAccuracyMode(bool value) async {
    await _settingsBox.put('isHighAccuracyMode', value);
  }

  String? getPin() => _settingsBox.get('app_pin');
  Future<void> setPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _settingsBox.delete('app_pin');
    } else {
      await _settingsBox.put('app_pin', pin);
    }
  }
}
