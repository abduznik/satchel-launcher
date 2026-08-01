import 'dart:io';
import 'package:path/path.dart' as p;

class WindowsLaunchService {
  /// Launches a Windows game exe. Handles .bat/.cmd via cmd.exe.
  /// Uses detached mode so the launcher doesn't block.
  static Future<void> launch(String exePath, {List<String> args = const []}) async {
    final dir = File(exePath).parent.path;
    final ext = p.extension(exePath).toLowerCase();

    if (ext == '.bat' || ext == '.cmd') {
      await Process.start(
        'cmd.exe',
        ['/c', exePath, ...args],
        workingDirectory: dir,
        mode: ProcessStartMode.detached,
      );
    } else {
      await Process.start(
        exePath,
        args,
        workingDirectory: dir,
        mode: ProcessStartMode.detached,
      );
    }
  }
}
