import 'dart:async';
import 'dart:io';

/// Tracks a running process by PID, with polling fallback for Wine/Crossover.
class ProcessTracker {
  int? _pid;
  String? _processName;
  Timer? _pollTimer;
  final Completer<void> _exitCompleter = Completer<void>();
  bool _exited = false;
  final void Function()? onExit;

  ProcessTracker({this.onExit});

  /// Attaches to an already-started process.
  void attach(Process process) {
    _pid = process.pid;
    _startTracking();
  }

  /// Attaches by PID and process name (for tracking game.exe after OmniSave launches it).
  void attachByName(int pid, String name) {
    _pid = pid;
    _processName = name;
    _startTracking();
  }

  void _startTracking() {
    // Listen to exit code (works on native Windows)
    if (_pid != null) {
      // We can't listen to exitCode of a process we didn't start,
      // so rely on polling.
    }

    // Poll every 2 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_exited) _checkIfAlive();
    });
  }

  void _checkIfAlive() {
    if (_exited || _pid == null) return;

    try {
      if (Platform.isWindows) {
        // Check by PID first
        Process.run('tasklist', ['/FI', 'PID eq $_pid', '/NH']).then((result) {
          if (_exited) return;
          final output = result.stdout.toString();
          final found = output.contains('$_pid') && !output.contains('INFO:');
          if (!found) {
            // PID gone — but maybe the game restarted with a new PID.
            // If we have a process name, search for it.
            if (_processName != null) {
              _searchByName(_processName!);
            } else {
              _markExited();
            }
          }
        }).catchError((_) {
          if (!_exited) _markExited();
        });
      } else {
        Process.run('kill', ['-0', '$_pid']).then((result) {
          if (result.exitCode != 0 && !_exited) {
            if (_processName != null) {
              _searchByName(_processName!);
            } else {
              _markExited();
            }
          }
        }).catchError((_) {
          if (!_exited) _markExited();
        });
      }
    } catch (_) {
      if (!_exited) _markExited();
    }
  }

  /// Searches for a process by name (e.g. "game.exe") and updates the tracked PID.
  void _searchByName(String name) async {
    try {
      final result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $name', '/NH']);
      final output = result.stdout.toString();
      if (output.contains(name) && !output.contains('INFO:')) {
        // Found it — extract the new PID
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.toLowerCase().contains(name.toLowerCase())) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final newPid = int.tryParse(parts[1]);
              if (newPid != null && newPid != _pid) {
                print('[ProcessTracker] Found $name with new PID: $newPid (was $_pid)');
                _pid = newPid;
                return; // Still alive with new PID
              }
            }
          }
        }
      }
      // Not found by name either — game truly exited
      if (!_exited) _markExited();
    } catch (_) {
      // Can't search — assume still alive to avoid false positives
    }
  }

  void _markExited() {
    if (_exited) return;
    _exited = true;
    _pollTimer?.cancel();
    print('[ProcessTracker] Process exited (PID: $_pid, name: $_processName)');
    onExit?.call();
    if (!_exitCompleter.isCompleted) _exitCompleter.complete();
  }

  bool get hasExited => _exited;
  int? get pid => _pid;
  String? get processName => _processName;

  Future<void> get whenExited => _exitCompleter.future;

  void markExited() => _markExited();

  void dispose() {
    _pollTimer?.cancel();
  }
}
