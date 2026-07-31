import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class EncryptionService {
  static const _keyFile = 'keys.enc';
  static const _ivLength = 16;

  late final String _machineKey;

  EncryptionService() {
    _machineKey = _deriveMachineKey();
  }

  String _deriveMachineKey() {
    // Derive a machine-specific key from hostname + username
    final hostname = Platform.localHostname;
    final username = Platform.environment['USERNAME'] ??
        Platform.environment['USER'] ??
        'default';
    final raw = '$hostname:$username:project_indie_salt';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  Future<String> _getStoragePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _keyFile);
  }

  Future<void> saveEncrypted(Map<String, String> data) async {
    final json = jsonEncode(data);
    final key = Key.fromUtf8(_machineKey);
    final iv = IV.fromSecureRandom(_ivLength);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(json, iv: iv);

    final filePath = await _getStoragePath();
    final file = File(filePath);

    // IV + encrypted data
    final combined = Uint8List.fromList(
      iv.bytes + encrypted.bytes,
    );

    await file.writeAsBytes(combined);
  }

  Future<Map<String, String>> loadEncrypted() async {
    final filePath = await _getStoragePath();
    final file = File(filePath);

    if (!await file.exists()) {
      return {};
    }

    final combined = await file.readAsBytes();
    if (combined.length < _ivLength) {
      return {};
    }

    final iv = IV(combined.sublist(0, _ivLength));
    final encrypted = Encrypted(combined.sublist(_ivLength));
    final key = Key.fromUtf8(_machineKey);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    try {
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }
}
