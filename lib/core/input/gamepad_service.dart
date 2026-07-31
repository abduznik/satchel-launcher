import 'dart:async';

enum GameAction {
  up,
  down,
  left,
  right,
  confirm,
  back,
  detail,
  favorite,
  l1,
  r1,
  start,
  select,
  confirmHold,
}

enum InputMode {
  mouse,
  gamepad,
  keyboard,
}

class GamepadService {
  static final GamepadService _instance = GamepadService._internal();
  factory GamepadService() => _instance;
  GamepadService._internal();

  final StreamController<GameAction> _actionController =
      StreamController<GameAction>.broadcast();
  Stream<GameAction> get actionStream => _actionController.stream;

  InputMode _currentMode = InputMode.mouse;
  InputMode get currentMode => _currentMode;

  Timer? _pollTimer;
  final Map<int, bool> _previousButtonStates = {};
  DateTime? _lastButtonPress;
  static const _debounceDuration = Duration(milliseconds: 80);
  static const _holdDuration = Duration(milliseconds: 500);

  // Custom button mappings
  Map<int, GameAction> _customMappings = {};

  // Default mapping (Xbox-style)
  final Map<int, GameAction> _defaultMapping = {
    0: GameAction.confirm,    // A
    1: GameAction.back,       // B
    2: GameAction.favorite,   // X
    3: GameAction.detail,     // Y
    4: GameAction.l1,         // LB
    5: GameAction.r1,         // RB
    8: GameAction.select,     // Back/View
    9: GameAction.start,      // Start/Menu
  };

  Map<int, GameAction> get _activeMapping =>
      _customMappings.isNotEmpty ? _customMappings : _defaultMapping;

  void startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkGamepadConnection();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  void _checkGamepadConnection() {
    // Flutter's gamepad support is limited on desktop
    // This is a placeholder for future implementation
  }

  void handleButtonPress(int buttonIndex) {
    final now = DateTime.now();

    // Debounce check
    if (_lastButtonPress != null &&
        now.difference(_lastButtonPress!) < _debounceDuration) {
      return;
    }

    // Hold detection
    if (_previousButtonStates[buttonIndex] == true) {
      if (_lastButtonPress != null &&
          now.difference(_lastButtonPress!) >= _holdDuration) {
        _actionController.add(GameAction.confirmHold);
      }
      return;
    }

    _previousButtonStates[buttonIndex] = true;
    _lastButtonPress = now;

    final action = _activeMapping[buttonIndex];
    if (action != null) {
      _actionController.add(action);
    }

    _currentMode = InputMode.gamepad;
  }

  void handleButtonRelease(int buttonIndex) {
    _previousButtonStates[buttonIndex] = false;
  }

  void handleAxisMove(double x, double y) {
    if (x.abs() > 0.5 || y.abs() > 0.5) {
      if (x.abs() > y.abs()) {
        _actionController.add(x > 0 ? GameAction.right : GameAction.left);
      } else {
        _actionController.add(y > 0 ? GameAction.down : GameAction.up);
      }
      _currentMode = InputMode.gamepad;
    }
  }

  void setMouseMode() {
    _currentMode = InputMode.mouse;
  }

  void setKeyboardMode() {
    _currentMode = InputMode.keyboard;
  }

  void setCustomMappings(Map<int, GameAction> mappings) {
    _customMappings = mappings;
  }

  void resetMappings() {
    _customMappings.clear();
  }

  void dispose() {
    _pollTimer?.cancel();
    _actionController.close();
  }
}

final gamepadService = GamepadService();
