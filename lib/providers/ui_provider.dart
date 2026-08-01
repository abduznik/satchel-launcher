import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input/gamepad_service.dart';

// Re-export InputMode so widgets can import from here
export '../core/input/gamepad_service.dart' show InputMode;

final inputModeProvider = StateProvider<InputMode>((ref) => InputMode.mouse);
final navigationLockedProvider = StateProvider<bool>((ref) => false);

// Legacy ChangeNotifier shim — kept so LibraryScreen / app.dart don't need rewrites
class UiProvider {
  void setMouseMode() {}
  void setKeyboardMode() {}
}

final uiProvider = Provider<UiProvider>((ref) => UiProvider());
