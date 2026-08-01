import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'services/drive_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure config directory exists FIRST so PID file can be read/written
  final hiveDir = Directory(DriveService.configPath);
  if (!await hiveDir.exists()) await hiveDir.create(recursive: true);

  // Kill orphaned processes from previous sessions
  _killOrphanedProcesses();

  // Init Hive
  Hive.init(hiveDir.path);
  await Hive.openBox('settings');
  await Hive.openBox('games');
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
        final result = Process.runSync('tasklist', ['/FI', 'PID eq $oldPid', '/NH']);
        final output = result.stdout.toString();
        if (output.contains('$oldPid') && !output.contains('INFO:')) {
          print('[Satchel] Killing orphaned process PID: $oldPid');
          Process.runSync('taskkill', ['/F', '/PID', '$oldPid']);
        }
      }
      pidFile.deleteSync();
    }
  } catch (_) {}
}

/// Writes current PID to a file so next startup can clean up if we ghost.
void _writePidFile() {
  try {
    if (!Platform.isWindows) return;
    // Get current PID using wmic (faster and more reliable than PowerShell)
    final result = Process.runSync('wmic', ['process', 'where', 'name="satchel.exe"', 'get', 'ProcessId', '/format:list']);
    final output = result.stdout.toString();
    // Parse "ProcessId=12345"
    final match = RegExp(r'ProcessId=(\d+)').firstMatch(output);
    if (match != null) {
      final pid = match.group(1);
      final pidFile = File(p.join(DriveService.configPath, 'satchel.pid'));
      pidFile.writeAsStringSync(pid!);
      print('[Satchel] Wrote PID file: $pid');
    }
  } catch (_) {}
}
