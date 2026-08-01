import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ui_provider.dart';
import 'known_controllers.dart';
import 'sdl_parser.dart';
import 'input_action_bus.dart';
import 'custom_controller_mappings.dart';
import 'gamepad_utils.dart';
import 'deadzone_config.dart';

enum GameAction {
  up, down, left, right,
  confirm, confirmHold, back, detail, favorite,
  verticalAxis, horizontalAxis,
  l1, r1, start, select,
}

enum InputMode { mouse, gamepad, keyboard }

class NormalizedInput {
  final GameAction action;
  final double value;
  const NormalizedInput({required this.action, required this.value});
}

final gamepadServiceProvider = Provider<GamepadService>((ref) {
  final service = GamepadService(ref);
  service.initialize();
  return service;
});

class AxisState {
  bool isNegativeActive = false;
  bool isPositiveActive = false;
  GameAction? heldDirection;
  Timer? holdDelayTimer;
  Timer? holdRepeatTimer;
}

class GamepadService extends WidgetsBindingObserver {
  final Ref _ref;
  StreamSubscription<GamepadEvent>? _subscription;
  Timer? _scanTimer;
  final Map<String, String> _controllerNames = {};
  final Map<String, AxisState> _axisStates = {};
  final _rawEventController = StreamController<GamepadEvent>.broadcast();
  final Map<String, Set<String>> _seenRawKeys = {};

  final Map<GameAction, DateTime> _lastDigitalPress = {};
  static const _digitalDebounce = Duration(milliseconds: 80);

  final Map<GameAction, DateTime> _buttonDownTime = {};
  Timer? _holdTimer;

  bool _appHasFocus = true;

  Stream<GamepadEvent> get rawEvents => _rawEventController.stream;

  GamepadService(this._ref);

  void initialize() async {
    debugPrint('[Controller] initialize: starting');
    await loadCustomMappings();
    await loadDeadzoneSettings();
    await SDLMappingParser.loadDatabase();
    debugPrint('[Controller] SDL database loaded');
    WidgetsBinding.instance.addObserver(this);
    _scan();
    _scanTimer = Timer.periodic(const Duration(seconds: 3), (_) => _scan());
    _subscription = Gamepads.events.listen(
      (event) {
        try { _handleGamepadEvent(event); } catch (e) {
          debugPrint('[Controller] event error: $e');
        }
      },
      onError: (err) => debugPrint('[Controller] stream error: $err'),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appHasFocus = state == AppLifecycleState.resumed;
  }

  void _scan() async {
    try {
      final controllers = await Gamepads.list();
      final currentIds = <String>{};
      for (var c in controllers) {
        currentIds.add(c.id);
        if (!_controllerNames.containsKey(c.id)) {
          debugPrint('[Controller] new: [${c.id}] ${c.name}');
          _controllerNames[c.id] = c.name;
        }
      }
      final stale = _controllerNames.keys.where((id) => !currentIds.contains(id)).toList();
      for (final id in stale) {
        _controllerNames.remove(id);
        _axisStates.remove(id);
        _seenRawKeys.remove(id);
      }
    } catch (e) {
      debugPrint('[Controller] scan error: $e');
    }
  }

  List<Map<String, String>> getDetectedControllers() {
    return _controllerNames.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  Map<String, GameAction> _getMappingFor(String controllerId) {
    final name = _controllerNames[controllerId] ?? '';
    for (final entry in customControllerMappings.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) return entry.value;
    }
    final sdl = SDLMappingParser.getMapping(name);
    if (sdl != null) return sdl;
    for (final entry in kControllerMappings.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) return entry.value;
    }
    return kDefaultMapping;
  }

  NormalizedInput? _normalize(GamepadEvent event) {
    final mapping = _getMappingFor(event.gamepadId);
    final directAction = mapping[event.key];
    if (directAction != null) return NormalizedInput(action: directAction, value: event.value);

    if (event.value != 0) {
      final polarityKey = GamepadUtils.encodeKey(event.key, event.value >= 0 ? 1 : -1);
      final polarAction = mapping[polarityKey];
      if (polarAction != null) return NormalizedInput(action: polarAction, value: event.value);
    }

    final key = event.key.toLowerCase();
    if (key == 'dwxpos' || key == 'dwypos' || key == 'dwrpos' || key == 'dwupos' || key == 'dwvpos') {
      final normalized = (event.value - 32767.0) / 32767.0;
      final controllerName = _controllerNames[event.gamepadId] ?? '';
      final dz = getDeadzoneForController(controllerName);
      final withDz = applyDeadzone(normalized, dz);
      final isX = key == 'dwxpos';
      return NormalizedInput(action: isX ? GameAction.horizontalAxis : GameAction.verticalAxis, value: withDz);
    }

    return null;
  }

  List<GameAction> _decodePOV(double rawValue) => GamepadUtils.decodePOV(rawValue);

  final Set<GameAction> _activePovDirections = {};

  void _handleGamepadEvent(GamepadEvent event) {
    if (_rawEventController.isClosed) return;
    _rawEventController.add(event);
    if (!_appHasFocus) return;

    _seenRawKeys.putIfAbsent(event.gamepadId, () => {}).add(event.key.toLowerCase());

    final keyLower = event.key.toLowerCase();
    if (keyLower == 'dwpov' || keyLower.startsWith('pov') || keyLower.startsWith('hat')) {
      _ref.read(inputModeProvider.notifier).state = InputMode.gamepad;
      final newDirections = _decodePOV(event.value).toSet();
      for (final dir in _activePovDirections.difference(newDirections)) {
        _deactivateDirection(dir, 'pov');
      }
      for (final dir in newDirections.difference(_activePovDirections)) {
        _triggerAction(dir, 1.0);
        _axisStates.putIfAbsent('pov', () => AxisState());
        _activateDirection(dir, 'pov', isDigital: true);
      }
      _activePovDirections..clear()..addAll(newDirections);
      return;
    }

    if (_ref.read(inputModeProvider) != InputMode.gamepad && event.value.abs() > 0.5) {
      _ref.read(inputModeProvider.notifier).state = InputMode.gamepad;
    }

    final normalized = _normalize(event);
    if (normalized == null) return;

    if (normalized.action == GameAction.horizontalAxis || normalized.action == GameAction.verticalAxis) {
      final axisKey = '${event.gamepadId}_${event.key}';
      final state = _axisStates.putIfAbsent(axisKey, () => AxisState());

      final bool isDpadInverted = event.key.contains('dpad') && normalized.action == GameAction.verticalAxis;
      final bool isAnalogInverted = analogInvertY && !event.key.contains('dpad') && normalized.action == GameAction.verticalAxis;
      final bool isInverted = isDpadInverted != isAnalogInverted;
      final double rawAdjusted = isInverted ? -event.value : event.value;

      final controllerName = _controllerNames[event.gamepadId] ?? '';
      final dz = getDeadzoneForController(controllerName);
      final isDirectInput = event.key.toLowerCase().startsWith('dw');
      final double adjustedValue = isDirectInput ? normalized.value : applyDeadzone(rawAdjusted, dz);

      if (adjustedValue < -0.5) {
        if (!state.isNegativeActive) {
          state.isNegativeActive = true;
          final a = normalized.action == GameAction.horizontalAxis ? GameAction.left : GameAction.up;
          _triggerAction(a, adjustedValue);
          _activateDirection(a, axisKey);
        }
      }
      if (adjustedValue > -0.15) {
        if (state.isNegativeActive) {
          state.isNegativeActive = false;
          _deactivateDirection(normalized.action == GameAction.horizontalAxis ? GameAction.left : GameAction.up, axisKey);
        }
      }
      if (adjustedValue > 0.5) {
        if (!state.isPositiveActive) {
          state.isPositiveActive = true;
          final a = normalized.action == GameAction.horizontalAxis ? GameAction.right : GameAction.down;
          _triggerAction(a, adjustedValue);
          _activateDirection(a, axisKey);
        }
      }
      if (adjustedValue < 0.15) {
        if (state.isPositiveActive) {
          state.isPositiveActive = false;
          _deactivateDirection(normalized.action == GameAction.horizontalAxis ? GameAction.right : GameAction.down, axisKey);
        }
      }
    } else {
      if (event.value.abs() > 0.5) {
        final now = DateTime.now();
        final last = _lastDigitalPress[normalized.action];
        if (last != null && now.difference(last) < _digitalDebounce) return;
        _lastDigitalPress[normalized.action] = now;

        if (_isDirectionAction(normalized.action)) {
          _triggerAction(normalized.action, event.value);
          final dk = 'digital_${normalized.action.name}';
          _axisStates.putIfAbsent(dk, () => AxisState());
          _activateDirection(normalized.action, dk, isDigital: true);
        } else {
          _buttonDownTime[normalized.action] = now;
          _holdTimer?.cancel();
          _holdTimer = Timer(const Duration(milliseconds: 500), () {
            if (_buttonDownTime.containsKey(normalized.action)) {
              _buttonDownTime.remove(normalized.action);
              _triggerAction(GameAction.confirmHold, 1.0);
            }
          });
          _triggerAction(normalized.action, event.value);
        }
      } else {
        if (_isDirectionAction(normalized.action)) {
          _deactivateDirection(normalized.action, 'digital_${normalized.action.name}');
        } else {
          if (_buttonDownTime.containsKey(normalized.action)) {
            _buttonDownTime.remove(normalized.action);
            _holdTimer?.cancel();
          }
        }
      }
    }
  }

  bool _isDirectionAction(GameAction action) =>
      action == GameAction.up || action == GameAction.down ||
      action == GameAction.left || action == GameAction.right;

  void _activateDirection(GameAction action, String axisKey, {bool isDigital = false}) {
    final state = _axisStates[axisKey];
    if (state == null || state.heldDirection == action) return;
    _cancelAxisTimers(state);
    state.heldDirection = action;
    if (isDigital) {
      state.holdDelayTimer = Timer(const Duration(milliseconds: 500), () {
        state.holdRepeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
          if (state.heldDirection == action && _isAxisStillActive(state, action)) {
            _triggerAction(action, 1.0);
          } else {
            _cancelAxisTimers(state);
            state.heldDirection = null;
          }
        });
      });
    }
  }

  void _deactivateDirection(GameAction action, String axisKey) {
    final state = _axisStates[axisKey];
    if (state == null || state.heldDirection != action) return;
    _cancelAxisTimers(state);
    state.heldDirection = null;
  }

  void _cancelAxisTimers(AxisState state) {
    state.holdDelayTimer?.cancel(); state.holdDelayTimer = null;
    state.holdRepeatTimer?.cancel(); state.holdRepeatTimer = null;
  }

  bool _isAxisStillActive(AxisState state, GameAction dir) {
    return (dir == GameAction.up || dir == GameAction.left)
        ? state.isNegativeActive
        : state.isPositiveActive;
  }

  void _triggerAction(GameAction action, double value) {
    inputActionBus.add(action);
    if (!_ref.read(navigationLockedProvider)) {
      switch (action) {
        case GameAction.up:    _moveFocus(TraversalDirection.up); break;
        case GameAction.down:  _moveFocus(TraversalDirection.down); break;
        case GameAction.left:  _moveFocus(TraversalDirection.left); break;
        case GameAction.right: _moveFocus(TraversalDirection.right); break;
        default: break;
      }
    }
  }

  void _moveFocus(TraversalDirection direction) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.context != null) {
      final ro = primary.context!.findRenderObject();
      if (ro != null && ro.attached) primary.focusInDirection(direction);
    }
  }

  // Legacy stubs kept so app.dart compiles unchanged
  void startPolling() {}
  void stopPolling() {}
  void setMouseMode() {}
  void setKeyboardMode() {}

  void dispose() {
    _subscription?.cancel();
    _scanTimer?.cancel();
    for (final state in _axisStates.values) { _cancelAxisTimers(state); }
    _rawEventController.close();
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Legacy singleton — app.dart still calls gamepadService.startPolling()
final gamepadService = _LegacyGamepadServiceStub();

class _LegacyGamepadServiceStub {
  void startPolling() {}
  void stopPolling() {}
  void setMouseMode() {}
  void setKeyboardMode() {}
  Stream<GameAction> get actionStream => const Stream.empty();
  void dispose() {}
}
