import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'services/drive_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kill orphaned processes from previous sessions using PID file
  _killOrphanedProcesses();

  // Store all Hive data in Config/ next to the exe — fully portable.
  final hiveDir = Directory(DriveService.configPath);
  if (!await hiveDir.exists()) await hiveDir.create(recursive: true);
  Hive.init(hiveDir.path);

  await Hive.openBox('settings');
  await Hive.openBox('games');

  // Ensure drive directories exist
  await DriveService.ensureDirectories();

  // Write current PID so next startup can kill us if we ghost
  _writePidFile();

  runApp(
    const ProviderScope(
      child: SatchelApp(),
    ),
  );
}

/// Kills any orphaned satchel.exe from a previous session using a PID file.
void _killOrphanedProcesses() {
  try {
    if (!Platform.isWindows) return;

    // Kill leftover OmniSave
    Process.run('taskkill', ['/F', '/IM', 'OmniSave.exe']);

    // Kill orphaned satchel.exe from previous session via PID file
    final pidFile = File(p.join(DriveService.configPath, 'satchel.pid'));
    if (pidFile.existsSync()) {
      final oldPid = int.tryParse(pidFile.readAsStringSync().trim());
      if (oldPid != null) {
        // Check if that PID is still running
        final result = Process.runSync('tasklist', ['/FI', 'PID eq $oldPid', '/NH']);
        final output = result.stdout.toString();
        if (output.contains('$oldPid') && !output.contains('INFO:')) {
          print('[Satchel] Killing orphaned process PID: $oldPid');
          Process.runSync('taskkill', ['/F', '/PID', '$oldPid']);
        }
      }
      pidFile.deleteSync();
    }

    // Also kill any other orphaned OmniSave processes
    Process.run('taskkill', ['/F', '/IM', 'OmniSave.exe']);
  } catch (_) {}
}

/// Writes current PID to a file so next startup can clean up if we ghost.
void _writePidFile() {
  try {
    if (!Platform.isWindows) return;
    // Get current PID via PowerShell since Dart doesn't expose it directly
    final result = Process.runSync('powershell', ['-Command', '[System.Diagnostics.Process]::GetCurrentProcess().Id']);
    final pid = int.tryParse(result.stdout.toString().trim());
    if (pid != null) {
      final pidFile = File(p.join(DriveService.configPath, 'satchel.pid'));
      pidFile.writeAsStringSync('$pid');
    }
  } catch (_) {}
}
