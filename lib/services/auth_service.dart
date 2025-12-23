import 'package:flutter/material.dart';

class AuthService with ChangeNotifier {
  bool _isLocked = true;

  bool get isLocked => _isLocked;

  void unlockApp() {
    _isLocked = false;
    notifyListeners();
  }

  void lockApp() {
    _isLocked = true;
    notifyListeners();
  }
}
