import 'dart:io';
import 'package:path/path.dart' as p;

class AutostartService {
  Future<void> generateAutoRunInf(String driveRoot, String exePath) async {
    final relativePath = p.relative(exePath, from: driveRoot);
    final content = '''
[AutoRun]
open=$relativePath
icon=$relativePath,0
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
