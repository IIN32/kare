import 'package:hive_flutter/hive_flutter.dart';
import '../models/medication.dart';

class LocalStorageService {
  static const String _boxName = 'medicationsBox';

  // Initialize Hive and register adapters
  Future<void> init() async {
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(MedicationAdapter());
    }
    await Hive.openBox<Medication>(_boxName);
  }

  // Get the open box
  Box<Medication> get _box => Hive.box<Medication>(_boxName);

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
    final stoppedMed = Medication(
      name: med.name,
      dosage: med.dosage,
      times: med.times,
      frequency: med.frequency,
      startDate: med.startDate,
      endDate: DateTime.now(),
    );
    
    if (med.isInBox) {
      await _box.put(med.key, stoppedMed);
    }
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
  }
}
