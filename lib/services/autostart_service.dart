import 'dart:io';
import 'package:path/path.dart' as p;

class AutostartService {
  Future<void> generateAutoRunInf(String driveRoot, String exePath) async {
    final appDir = p.dirname(exePath);
    // Use the .ico file from windows/runner/resources if it exists,
    // otherwise fall back to the exe (which has the icon embedded)
    final icoPath = p.join(appDir, 'app_icon.ico');
    final icoFile = File(icoPath);
    final iconRef = await icoFile.exists()
        ? p.relative(icoPath, from: driveRoot)
        : '${p.relative(exePath, from: driveRoot)},0';

    final relativeExe = p.relative(exePath, from: driveRoot);
    final content = '''
[AutoRun]
open=$relativeExe
icon=$iconRef
action=Launch Satchel
''';

    final file = File(p.join(driveRoot, 'AutoRun.inf'));
    await file.writeAsString(content);
  }

  Future<bool> hasAutoRunInf(String driveRoot) async {
    final file = File(p.join(driveRoot, 'AutoRun.inf'));
    return file.exists();
  }

  Future<void> removeAutoRunInf(String driveRoot) async {
    final file = File(p.join(driveRoot, 'AutoRun.inf'));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
