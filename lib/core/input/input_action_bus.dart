import 'dart:async';
import 'gamepad_service.dart';

/// A global broadcast stream for controller and keyboard actions.
final inputActionBus = StreamController<GameAction>.broadcast();
