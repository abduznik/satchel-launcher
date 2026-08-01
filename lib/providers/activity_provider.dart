import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivityStatus { running, done, error }

class ActivityState {
  final String message;
  final String? detail;
  final ActivityStatus status;
  final int nonce;

  const ActivityState({
    required this.message,
    this.detail,
    this.status = ActivityStatus.running,
    required this.nonce,
  });
}

final activityProvider =
    StateNotifierProvider<ActivityNotifier, ActivityState?>(
  (ref) => ActivityNotifier(),
);

class ActivityNotifier extends StateNotifier<ActivityState?> {
  ActivityNotifier() : super(null);

  int _nonce = 0;

  void show(String message, {String? detail}) {
    state = ActivityState(
      message: message,
      detail: detail,
      status: ActivityStatus.running,
      nonce: _nonce++,
    );
  }

  void update(String message, {String? detail}) {
    if (state == null) return;
    state = ActivityState(
      message: message,
      detail: detail ?? state!.detail,
      status: ActivityStatus.running,
      nonce: _nonce++,
    );
  }

  void success({String? detail}) {
    _finish(ActivityStatus.done, detail: detail);
  }

  void error({String? detail}) {
    _finish(ActivityStatus.error, detail: detail);
  }

  void _finish(ActivityStatus status, {String? detail}) {
    if (state == null) return;
    state = ActivityState(
      message: state!.message,
      detail: detail ?? state!.detail,
      status: status,
      nonce: _nonce++,
    );
  }

  void hide() {
    state = null;
  }
}
