import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'services/drive_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kill orphaned processes from previous sessions
  _killOrphanedProcesses();

  // Wait for icudtl.dat to be unlocked (double-sided handshake)
  // If the previous instance is still closing, it holds a lock on this file.
  await _waitForFileUnlock();

  // Ensure config directory exists
  final hiveDir = Directory(DriveService.configPath);
  if (!await hiveDir.exists()) await hiveDir.create(recursive: true);

  // Init Hive
  Hive.init(hiveDir.path);
  await Hive.openBox('settings');
  await Hive.openBox('games');
  await DriveService.ensureDirectories();

  // Write current PID for next startup cleanup
  _writePidFile();

  runApp(
    const ProviderScope(
      child: SatchelApp(),
    ),
  );
}

/// Waits for icudtl.dat to be unlocked by the previous instance.
/// If the file is locked, the previous app is still running — we wait
/// for it to release the file handle before starting.
Future<void> _waitForFileUnlock() async {
  if (!Platform.isWindows) return;

  // Find icudtl.dat relative to the exe
  final exeDir = p.dirname(Platform.resolvedExecutable);
  final icuFile = File(p.join(exeDir, 'data', 'icudtl.dat'));

  if (!await icuFile.exists()) return;

  // Try to open the file exclusively — if it fails, it's locked
  for (var i = 0; i < 50; i++) {
    try {
      // RandomAccessLock: opens file with exclusive access
      final handle = await icuFile.open(mode: FileMode.read);
      await handle.close();
      // File is unlocked — we can proceed
      if (i > 0) {
        print('[Satchel] icudtl.dat unlocked after ${i * 100}ms');
      }
      return;
    } catch (_) {
      // File is locked — previous instance still running
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Timeout after 5 seconds — proceed anyway
  print('[Satchel] icudtl.dat still locked after 5s, proceeding anyway');
}

/// Kills all orphaned satchel.exe and OmniSave.exe processes.
void _killOrphanedProcesses() {
  try {
    if (!Platform.isWindows) return;

    // Kill all OmniSave processes
    Process.runSync('taskkill', ['/F', '/IM', 'OmniSave.exe']);

    // Kill orphaned satchel.exe processes
    final result = Process.runSync('taskkill', ['/IM', 'satchel.exe', '/F']);
    final output = result.stdout.toString();
    if (output.contains('SUCCESS')) {
      print('[Satchel] Killed orphaned processes');
      sleep(const Duration(milliseconds: 200));
    }
  } catch (_) {}
}

/// Writes current PID to a file for next startup cleanup.
void _writePidFile() {
  try {
    if (!Platform.isWindows) return;
    final result = Process.runSync('wmic', [
      'process', 'where', 'name="satchel.exe"', 'get', 'ProcessId', '/format:list'
    ]);
    final output = result.stdout.toString();
    final match = RegExp(r'ProcessId=(\d+)').firstMatch(output);
    if (match != null) {
      final pid = match.group(1);
      final pidFile = File(p.join(DriveService.configPath, 'satchel.pid'));
      pidFile.writeAsStringSync(pid!);
      print('[Satchel] Wrote PID: $pid');
    }
  } catch (_) {}
}
