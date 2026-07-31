import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input/gamepad_service.dart';

class UiProvider extends ChangeNotifier {
  InputMode _inputMode = InputMode.mouse;
  bool _navigationLocked = false;

  InputMode get inputMode => _inputMode;
  bool get navigationLocked => _navigationLocked;

  UiProvider() {
    _listenToInput();
  }

  void _listenToInput() {
    gamepadService.actionStream.listen((_) {
      if (_inputMode != InputMode.gamepad) {
        _inputMode = InputMode.gamepad;
        notifyListeners();
      }
    });
  }

  void setMouseMode() {
    if (_inputMode != InputMode.mouse) {
      _inputMode = InputMode.mouse;
      gamepadService.setMouseMode();
      notifyListeners();
    }
  }

  void setKeyboardMode() {
    if (_inputMode != InputMode.keyboard) {
      _inputMode = InputMode.keyboard;
      gamepadService.setKeyboardMode();
      notifyListeners();
    }
  }

  void setGamepadMode() {
    if (_inputMode != InputMode.gamepad) {
      _inputMode = InputMode.gamepad;
      notifyListeners();
    }
  }

  void lockNavigation() {
    _navigationLocked = true;
    notifyListeners();
  }

  void unlockNavigation() {
    _navigationLocked = false;
    notifyListeners();
  }
}

final uiProvider = ChangeNotifierProvider<UiProvider>((ref) {
  return UiProvider();
});
