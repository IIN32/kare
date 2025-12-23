import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/profile.dart';
import '../models/medication.dart'; // For deleting associated meds

class ProfileService with ChangeNotifier {
  static const String _profilesBoxName = 'profilesBox';
  static const String _medsBoxName = 'medicationsBox'; // To access medications
  static const String _settingsBoxName = 'settingsBox';
  static const String _currentProfileKey = 'currentProfileId';

  Box<Profile> get _profilesBox => Hive.box<Profile>(_profilesBoxName);
  Box<Medication> get _medsBox => Hive.box<Medication>(_medsBoxName);
  Box get _settingsBox => Hive.box(_settingsBoxName);
  
  List<Profile> getProfiles() {
    return _profilesBox.values.toList();
  }

  String get currentProfileId => _settingsBox.get(_currentProfileKey, defaultValue: 'default');

  Profile? get currentProfile => _profilesBox.get(currentProfileId);

  int get points => currentProfile?.points ?? 0;

  Future<void> setCurrentProfile(String profileId) async {
    await _settingsBox.put(_currentProfileKey, profileId);
    notifyListeners();
  }

  Future<void> addProfile(Profile profile) async {
    await _profilesBox.put(profile.id, profile);
    notifyListeners();
  }
  
  Future<void> addPoints(int points) async {
    final profile = currentProfile;
    if (profile != null) {
      profile.points += points;
      await profile.save();
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String profileId) async {
    if (profileId == 'default') return; // Cannot delete the default profile

    // Delete the profile
    await _profilesBox.delete(profileId);

    // Delete all medications associated with this profile
    final medsToDelete = _medsBox.values.where((med) => med.profileId == profileId).toList();
    for (var med in medsToDelete) {
      if (med.isInBox) {
        await med.delete();
      }
    }

    // Switch back to the default profile
    await setCurrentProfile('default');
    
    notifyListeners();
  }

  Future<void> init() async {
    await Hive.openBox<Profile>(_profilesBoxName);
    // DO NOT create a default profile here, so the setup screen can run.
  }
}
