import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'platform_service.dart';

class WindowsLaunchService {
  /// Launches a Windows game exe. Handles .bat/.cmd via cmd.exe.
  /// Returns the Process handle for tracking, or null if launch failed.
  static Future<Process?> launch(String exePath, {List<String> args = const []}) async {
    final dir = File(exePath).parent.path;
    final ext = p.extension(exePath).toLowerCase();

    print('[Launch] Attempting: $exePath');
    print('[Launch] Working dir: $dir');
    print('[Launch] Wine: ${PlatformService.isWinLike}');

    // Strategy 1: Standard launch
    if (ext == '.bat' || ext == '.cmd') {
      final p = await _tryLaunch('cmd.exe', ['/c', exePath, ...args], dir);
      if (p != null) return p;
    }

    var process = await _tryLaunch(exePath, args, dir);
    if (process != null) return process;

    // Strategy 2: Under Wine, try cmd /c start
    if (PlatformService.isWinLike) {
      print('[Launch] Trying cmd /c start');
      process = await _tryLaunch(
        'cmd.exe',
        ['/c', 'start', '', '"$exePath"'],
        dir,
      );
      if (process != null) return process;
    }

    print('[Launch] All strategies failed for $exePath');
    return null;
  }

  static Future<Process?> _tryLaunch(
    String executable,
    List<String> args,
    String workingDir,
  ) async {
    try {
      final mode = PlatformService.isWinLike
          ? ProcessStartMode.normal
          : ProcessStartMode.detached;

      final process = await Process.start(
        executable,
        args,
        workingDirectory: workingDir,
        mode: mode,
      ).timeout(const Duration(seconds: 10));

      print('[Launch] Success! PID: ${process.pid}');
      // Don't await exitCode — let it run
      process.exitCode.catchError((_) => -1);
      return process;
    } catch (e) {
      print('[Launch] Failed: $executable — $e');
      return null;
    }
  }
}
