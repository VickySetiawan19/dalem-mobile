import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:Dalem/components/offline_storage.dart';
import 'package:Dalem/services/offline_seed_data.dart';

/// Centralized API service with 3-tier resilient offline cache fallback.
/// Tier 1: Live HTTP Network (with 10s timeout)
/// Tier 2: Persistent Local Storage Cache (SharedPreferences)
/// Tier 3: Pre-packaged Curated Seed Dataset (Guarantees zero blank screens)
class BpsApiService {
  /// Fetches JSON Object (`Map<String, dynamic>`) from [url].
  /// On success, automatically caches data in [OfflineStorage].
  /// On failure/offline, falls back to cached data or offline seed data.
  static Future<Map<String, dynamic>> fetchJson(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          final jsonResponse = decoded.cast<String, dynamic>();
          // Cache successful network response
          await OfflineStorage.saveData(url, jsonResponse);
          jsonResponse['_is_offline'] = false;
          return jsonResponse;
        }
      }
      throw Exception('API Error: ${response.statusCode} - ${response.reasonPhrase}');
    } catch (e) {
      debugPrint('Live network fetch failed ($url): $e. Checking offline cache...');

      // 1. Try local cache from previous successful visits
      final offlineData = await OfflineStorage.loadData(url);
      if (offlineData != null && offlineData is Map) {
        final cached = offlineData.cast<String, dynamic>();
        cached['_is_offline'] = true;
        cached['_offline_source'] = 'cache';
        debugPrint('Loaded from persistent offline cache for: $url');
        return cached;
      }

      // 2. Try pre-packaged official seed dataset
      final seedData = _resolveSeedData(url);
      if (seedData != null) {
        seedData['_is_offline'] = true;
        seedData['_offline_source'] = 'seed';
        debugPrint('Loaded from pre-packaged seed dataset for: $url');
        return seedData;
      }

      rethrow;
    }
  }

  /// Fetches data list from a BPS API list endpoint.
  static Future<List<dynamic>> fetchDataList(String url) async {
    try {
      final jsonResponse = await fetchJson(url);
      if (jsonResponse['data'] != null &&
          jsonResponse['data'] is List &&
          (jsonResponse['data'] as List).length > 1) {
        final listData = jsonResponse['data'][1] as List<dynamic>;
        return listData;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Resolve pre-packaged seed dataset matching the requested URL
  static Map<String, dynamic>? _resolveSeedData(String url) {
    final lower = url.toLowerCase();

    // Strategic indicators list
    if (lower.contains('tablestatistic') && lower.contains('strategis')) {
      return OfflineSeedData.getStrategicTablesList();
    }

    // Dynamic indicator data table (var=xxx or varId)
    final varMatch = RegExp(r'var=([^&]+)').firstMatch(url);
    if (varMatch != null) {
      final varId = varMatch.group(1) ?? 'kemiskinan';
      return OfflineSeedData.getDynamicTableData(varId);
    }

    return null;
  }

  /// Manually invalidate cache for a specific [url].
  static Future<void> invalidateCache(String url) async {
    await OfflineStorage.clearData(url);
  }
}
