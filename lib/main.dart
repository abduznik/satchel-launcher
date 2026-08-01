import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'services/drive_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Kill orphaned processes from previous sessions
  _killOrphanedProcesses();

  // Step 2: Wait for all old satchel processes to fully die
  await _waitForProcessCleanup();

  // Step 3: Init Hive and app
  final hiveDir = Directory(DriveService.configPath);
  if (!await hiveDir.exists()) await hiveDir.create(recursive: true);

  Hive.init(hiveDir.path);
  await Hive.openBox('settings');
  await Hive.openBox('games');
  await DriveService.ensureDirectories();

  _writePidFile();

  runApp(
    const ProviderScope(
      child: SatchelApp(),
    ),
  );
}

/// Kills orphaned processes.
void _killOrphanedProcesses() {
  try {
    if (!Platform.isWindows) return;
    Process.runSync('taskkill', ['/F', '/IM', 'OmniSave.exe']);
    Process.runSync('taskkill', ['/IM', 'satchel.exe', '/F']);
  } catch (_) {}
}

/// Waits for all satchel.exe processes (except current) to fully die.
/// Polls tasklist every 100ms, gives up after 5 seconds.
Future<void> _waitForProcessCleanup() async {
  if (!Platform.isWindows) return;

  final currentPid = _getCurrentPid();

  for (var i = 0; i < 50; i++) {
    final pids = _getRunningPids('satchel.exe');
    // Remove current process from the list
    pids.removeWhere((pid) => pid == currentPid);

    if (pids.isEmpty) return; // No other satchel processes — we're good

    print('[Satchel] Waiting for orphaned PIDs to die: $pids');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  print('[Satchel] Timeout waiting for cleanup, proceeding anyway');
}

/// Gets the current process PID.
int _getCurrentPid() {
  try {
    final result = Process.runSync('wmic', [
      'process', 'where', 'name="satchel.exe"', 'get', 'ProcessId', '/format:list'
    ]);
    final output = result.stdout.toString();
    // wmic returns ALL satchel PIDs — the last one is usually the newest (current)
    final pids = <int>[];
    for (final match in RegExp(r'ProcessId=(\d+)').allMatches(output)) {
      final pid = int.tryParse(match.group(1)!);
      if (pid != null) pids.add(pid);
    }
    return pids.isNotEmpty ? pids.last : 0;
  } catch (_) {
    return 0;
  }
}

/// Gets all PIDs for a given process name.
List<int> _getRunningPids(String processName) {
  final pids = <int>[];
  try {
    final result = Process.runSync('tasklist', [
      '/FI', 'IMAGENAME eq $processName', '/NH'
    ]);
    final output = result.stdout.toString();
    for (final match in RegExp(r'(\d+)\s+\S+\s+\d+').allMatches(output)) {
      final pid = int.tryParse(match.group(1)!);
      if (pid != null) pids.add(pid);
    }
  } catch (_) {}
  return pids;
}

/// Writes current PID for next startup.
void _writePidFile() {
  try {
    if (!Platform.isWindows) return;
    final pid = _getCurrentPid();
    if (pid > 0) {
      final pidFile = File(p.join(DriveService.configPath, 'satchel.pid'));
      pidFile.writeAsStringSync('$pid');
      print('[Satchel] Wrote PID: $pid');
    }
  } catch (_) {}
}
