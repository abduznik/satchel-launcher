import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'drive_service.dart';

class EncryptionService {
  static const _keyFile = 'keys.enc';
  static const _ivLength = 16;

  late final String _machineKey;

  EncryptionService() {
    _machineKey = _deriveMachineKey();
    print('[EncryptionService] Storage: ${_getStoragePath()}');
  }

  String _deriveMachineKey() {
    final hostname = Platform.localHostname;
    final username = Platform.environment['USERNAME'] ??
        Platform.environment['USER'] ??
        'default';
    final raw = '$hostname:$username:satchel_salt';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  String _getStoragePath() {
    return p.join(DriveService.configPath, _keyFile);
  }

  Future<void> saveEncrypted(Map<String, String> data) async {
    try {
      print('[EncryptionService] Saving ${data.length} keys');
      final json = jsonEncode(data);
      final key = enc.Key.fromUtf8(_machineKey);
      final iv = enc.IV.fromSecureRandom(_ivLength);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(json, iv: iv);

      final filePath = _getStoragePath();
      final dir = Directory(p.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(filePath);
      final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
      await file.writeAsBytes(combined);
      print('[EncryptionService] Saved OK ($filePath, ${combined.length} bytes)');
    } catch (e) {
      print('[EncryptionService] SAVE ERROR: $e');
    }
  }

  Future<Map<String, String>> loadEncrypted() async {
    try {
      final filePath = _getStoragePath();
      final file = File(filePath);

      if (!await file.exists()) {
        print('[EncryptionService] No file at $filePath');
        return {};
      }

      final combined = await file.readAsBytes();
      if (combined.length < _ivLength) {
        print('[EncryptionService] File too small');
        return {};
      }

      final iv = enc.IV(combined.sublist(0, _ivLength));
      final encrypted = enc.Encrypted(combined.sublist(_ivLength));
      final key = enc.Key.fromUtf8(_machineKey);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;
      final result = data.map((k, v) => MapEntry(k, v.toString()));
      print('[EncryptionService] Loaded OK: ${result.keys.toList()}');
      return result;
    } catch (e) {
      print('[EncryptionService] LOAD ERROR: $e');
      return {};
    }
  }
}
