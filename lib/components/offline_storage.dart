import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineStorage {
  static const String _timestampSuffix = '_cached_at';

  /// Save data to local cache with timestamp
  static Future<void> saveData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = json.encode(data);
      await prefs.setString(key, jsonData);
      await prefs.setString('$key$_timestampSuffix', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Load data from local cache
  static Future<dynamic> loadData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(key);
      if (jsonData != null) {
        return json.decode(jsonData);
      }
    } catch (_) {}
    return null;
  }

  /// Get the timestamp of when this key was cached
  static Future<DateTime?> getCachedTimestamp(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString('$key$_timestampSuffix');
      if (tsStr != null) {
        return DateTime.tryParse(tsStr);
      }
    } catch (_) {}
    return null;
  }

  /// Clear specific cached data
  static Future<void> clearData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      await prefs.remove('$key$_timestampSuffix');
    } catch (_) {}
  }
}
