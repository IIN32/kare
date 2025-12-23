import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../main.dart'; // To access global authService

class PinScreen extends StatefulWidget {
  final bool isSettingPin;

  const PinScreen({super.key, this.isSettingPin = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _enteredPin = '';
  String? _firstPin;
  String _prompt = 'Enter your PIN';

  @override
  void initState() {
    super.initState();
    if (widget.isSettingPin) {
      _prompt = 'Create a new 4-digit PIN';
    }
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
      });

      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), _verifyPin);
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verifyPin() {
    if (widget.isSettingPin) {
      if (_firstPin == null) {
        _firstPin = _enteredPin;
        setState(() {
          _prompt = 'Confirm your PIN';
          _enteredPin = '';
        });
      } else {
        if (_firstPin == _enteredPin) {
          LocalStorageService().setPin(_enteredPin).then((_) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN has been set!')));
            Navigator.pop(context, true); // Success
          });
        } else {
          setState(() {
            _prompt = 'PINs do not match. Please try again.';
            _firstPin = null;
            _enteredPin = '';
          });
        }
      }
    } else {
      final storedPin = LocalStorageService().getPin();
      if (_enteredPin == storedPin) {
        authService.unlockApp();
      } else {
        setState(() {
          _prompt = 'Incorrect PIN. Please try again.';
          _enteredPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isSettingPin ? AppBar(title: const Text('Set PIN')) : null,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(_prompt, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPin.length 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  ),
                );
              }),
            ),
            const Spacer(flex: 3),
            _buildKeypad(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) {
          return widget.isSettingPin
              ? Container()
              : Icon(Icons.fingerprint, size: 36, color: Colors.grey.shade400);
        }
        if (index == 11) {
          return IconButton(
            icon: const Icon(Icons.backspace_outlined, size: 28),
            onPressed: _onDelete,
          );
        }
        final number = (index == 10) ? '0' : (index + 1).toString();
        return TextButton(
          style: TextButton.styleFrom(shape: const CircleBorder(), backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.5)),
          child: Text(number, style: Theme.of(context).textTheme.headlineMedium),
          onPressed: () => _onNumberPressed(number),
        );
      },
    );
  }
}
