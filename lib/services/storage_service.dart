import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Import conditionnel correct
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    if (dart.library.html) 'dummy_storage.dart';

class StorageService {
  static dynamic _storage;

  static Future<void> initStorage() async {
    if (kIsWeb) {
      _storage = await SharedPreferences.getInstance();
    } else {
      _storage = FlutterSecureStorage();
    }
  }

  static Future<void> setValue(String key, String value) async {
    if (kIsWeb) {
      await (_storage as SharedPreferences).setString(key, value);
    } else {
      await (_storage as FlutterSecureStorage).write(key: key, value: value);
    }
  }

  static Future<String?> getValue(String key) async {
    if (kIsWeb) {
      return (_storage as SharedPreferences).getString(key);
    } else {
      return await (_storage as FlutterSecureStorage).read(key: key);
    }
  }

  static Future<void> removeValue(String key) async {
    if (kIsWeb) {
      await (_storage as SharedPreferences).remove(key);
    } else {
      await (_storage as FlutterSecureStorage).delete(key: key);
    }
  }
}
