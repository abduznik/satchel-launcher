import 'dart:async';
import 'dart:io';

/// Tracks a running game process and detects when it exits.
class ProcessTracker {
  Process? _process;
  Timer? _pollTimer;
  final Completer<void> _exitCompleter = Completer<void>();
  bool _exited = false;
  final void Function()? onExit;

  ProcessTracker({this.onExit});

  /// Attaches to an already-started process for tracking.
  void attach(Process process) {
    _process = process;
    _startTracking();
  }

  /// Starts tracking via exit code future (works on native Windows).
  /// Also polls periodically as a fallback (works under Wine/Crossover
  /// where the exit code future may not fire reliably).
  void _startTracking() {
    if (_process == null) return;

    // Method 1: Listen to exit code (native Windows, reliable)
    _process!.exitCode.then((_) {
      if (!_exited) _markExited();
    }).catchError((_) {
      // Ignore — fallback polling will catch it
    });

    // Method 2: Poll process every 2 seconds (Wine/Crossover fallback)
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_exited) return;
      _checkIfAlive();
    });
  }

  /// Checks if the process is still alive by polling.
  /// Under Wine, we check if the PID is still running.
  void _checkIfAlive() {
    if (_process == null || _exited) return;

    try {
      // On Windows/Wine: try to find the process by PID.
      // If the process is gone, this will throw or return empty.
      final pid = _process!.pid;

      // Use tasklist on Windows, ps on Unix — but under Wine we're
      // still in Windows mode so tasklist works.
      if (Platform.isWindows) {
        Process.run('tasklist', ['/FI', 'PID eq $pid', '/NH']).then((result) {
          if (!_exited) {
            // If tasklist doesn't find the PID, the process is gone
            final output = result.stdout.toString();
            if (!output.contains('$pid') || output.contains('INFO:')) {
              _markExited();
            }
          }
        }).catchError((_) {
          // If tasklist fails, assume process is gone after a grace period
        });
      } else {
        // On native macOS/Linux (unlikely for this launcher, but just in case)
        Process.run('kill', ['-0', '$pid']).then((result) {
          // kill -0 succeeds if process exists
          if (result.exitCode != 0 && !_exited) {
            _markExited();
          }
        }).catchError((_) {
          if (!_exited) _markExited();
        });
      }
    } catch (_) {
      // Process access error — likely means it's gone
      if (!_exited) _markExited();
    }
  }

  void _markExited() {
    if (_exited) return;
    _exited = true;
    _pollTimer?.cancel();
    print('[ProcessTracker] Process exited (PID: ${_process?.pid})');
    onExit?.call();
    if (!_exitCompleter.isCompleted) _exitCompleter.complete();
  }

  /// Whether the process has exited.
  bool get hasExited => _exited;

  /// Future that completes when the process exits.
  Future<void> get whenExited => _exitCompleter.future;

  /// Manually mark as exited (e.g. if we can't track it).
  void markExited() => _markExited();

  /// Cleanup.
  void dispose() {
    _pollTimer?.cancel();
  }
}
