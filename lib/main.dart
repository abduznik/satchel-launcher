import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/drive_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kill any orphaned OmniSave processes from previous sessions
  _killOrphanedProcesses();

  // Store all Hive data in Config/ next to the exe — fully portable.
  final hiveDir = Directory(DriveService.configPath);
  if (!await hiveDir.exists()) await hiveDir.create(recursive: true);
  Hive.init(hiveDir.path);

  await Hive.openBox('settings');
  await Hive.openBox('games');

  // Ensure drive directories exist
  await DriveService.ensureDirectories();

  runApp(
    const ProviderScope(
      child: SatchelApp(),
    ),
  );
}

void _killOrphanedProcesses() {
  try {
    if (Platform.isWindows) {
      Process.run('taskkill', ['/F', '/IM', 'OmniSave.exe']);
    }
  } catch (_) {}
}
