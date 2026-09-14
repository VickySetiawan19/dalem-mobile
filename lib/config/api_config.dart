import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API configuration loaded from `.env` file.
class ApiConfig {
  /// BPS Web API key.
  static String get apiKey => dotenv.env['BPS_API_KEY'] ?? '';

  /// BPS domain code (Kabupaten Demak = 3321).
  static String get domain => dotenv.env['BPS_DOMAIN'] ?? '3321';

  /// Base URL for BPS Web API v1.
  static const String baseUrl = 'https://webapi.bps.go.id/v1/api';

  /// Builds the full URL for a BPS API list endpoint.
  static String listUrl({
    required String model,
    String lang = 'ind',
    String? keyword,
    String? year,
    int? page,
    int perpage = 10,
  }) {
    var url = '$baseUrl/list/model/$model/lang/$lang/domain/$domain';
    if (year != null && year.isNotEmpty && year != 'Semua') {
      url += '/year/$year';
    }
    if (keyword != null && keyword.isNotEmpty) {
      url += '/keyword/$keyword';
    }
    if (page != null) {
      url += '/page/$page/perpage/$perpage';
    }
    url += '/key/$apiKey/';
    return url;
  }

  /// Builds the full URL for a BPS API view (detail) endpoint.
  static String viewUrl({
    required String model,
    required String id,
    String lang = 'ind',
  }) {
    return '$baseUrl/view/domain/$domain/model/$model/lang/$lang/id/$id/key/$apiKey/';
  }

  /// Returns the dynamic BPS year range code up to the current year (e.g. '026' for 2026, '027' for 2027).
  /// This queries all available data periods up to the current year from the BPS API data endpoint.
  static String get defaultTh {
    final currentYear = DateTime.now().year;
    final yy = (currentYear % 100).toString().padLeft(2, '0');
    return '0$yy';
  }

  /// Builds the full URL for a BPS API data endpoint.
  static String dataUrl({
    required String varId,
    String? th,
  }) {
    final thParam = (th != null && th.isNotEmpty) ? th : defaultTh;
    return '$baseUrl/list?domain=$domain&model=data&lang=ind&var=$varId&th=$thParam&key=$apiKey';
  }

  /// Builds the URL for BPS API SIMDASI (interoperabilitas) endpoint (tableType == '3').
  static String simdasiUrl({
    required String idTabel,
    int? tahun,
    String id = '25',
  }) {
    final targetTahun = tahun ?? DateTime.now().year;
    final wilayah = '${domain}000';
    return '$baseUrl/interoperabilitas/datasource/simdasi/id/$id/tahun/$targetTahun/id_tabel/$idTabel/wilayah/$wilayah/key/$apiKey';
  }

  // ==========================================
  // PINTAR KBLI API (Sensus Ekonomi 2026)
  // ==========================================

  /// Base URL for PINTAR KBLI API.
  static String get kbliBaseUrl {
    final configured = dotenv.env['KBLI_API_BASE_URL'];
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim().replaceAll(RegExp(r'/+$'), '');
    }
    return 'https://demakai.bpsdemak.com/api/v1';
  }

  /// Search endpoint URL (`GET /search?q=...&type=...&limit=...`).
  static String kbliSearchUrl({
    required String query,
    String? type,
    int limit = 15,
  }) {
    final encodedQuery = Uri.encodeComponent(query);
    var url = '$kbliBaseUrl/search?q=$encodedQuery&limit=$limit';
    if (type != null && type.isNotEmpty && type != 'ALL') {
      url += '&type=${Uri.encodeComponent(type)}';
    }
    return url;
  }

  /// Hierarchy exploration URL (`GET /kbli/hierarchy?parent=...`).
  static String kbliHierarchyUrl({String? parent}) {
    var url = '$kbliBaseUrl/kbli/hierarchy';
    if (parent != null && parent.isNotEmpty) {
      url += '?parent=${Uri.encodeComponent(parent)}';
    }
    return url;
  }

  /// Sync check endpoint URL (`GET /sync/check`).
  static String get kbliSyncCheckUrl => '$kbliBaseUrl/sync/check';

  /// Sync bundle download URL (`GET /sync/bundle`).
  static String get kbliSyncBundleUrl => '$kbliBaseUrl/sync/bundle';

  /// AI Model embedding download URL (`GET /sync/model`).
  static String get kbliModelDownloadUrl => '$kbliBaseUrl/sync/model';

  /// Single submission endpoint URL (`POST /submissions`).
  static String get kbliSubmissionUrl => '$kbliBaseUrl/submissions';

  /// Bulk sync submissions endpoint URL (`POST /submissions/bulk-sync`).
  static String get kbliBulkSyncUrl => '$kbliBaseUrl/submissions/bulk-sync';
}

