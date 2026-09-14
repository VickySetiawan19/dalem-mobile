import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Dalem/config/api_config.dart';

class PublicationProvider extends ChangeNotifier {
  final List<dynamic> _publications = [];
  int _currentPage = 1;
  String? _selectedYear;
  String? _keyword;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _hasMoreData = true;
  bool _isError = false;

  List<dynamic> get publications => List.unmodifiable(_publications);
  int get currentPage => _currentPage;
  String? get selectedYear => _selectedYear;
  String? get keyword => _keyword;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;
  bool get hasMoreData => _hasMoreData;
  bool get isError => _isError;

  /// Memuat data publikasi awal atau saat filter tahun/kata kunci berubah.
  Future<void> fetchPublications({
    bool isRefresh = false,
    String? year,
    String? keyword,
  }) async {
    final cleanYear = (year == 'Semua' || year == null || year.trim().isEmpty)
        ? null
        : year.trim();
    final cleanKeyword = (keyword == null || keyword.trim().isEmpty)
        ? null
        : keyword.trim();

    final yearChanged = cleanYear != _selectedYear;
    final keywordChanged = cleanKeyword != _keyword;

    if (isRefresh || yearChanged || keywordChanged) {
      _selectedYear = cleanYear;
      _keyword = cleanKeyword;
      _currentPage = 1;
      _hasMoreData = true;
      _isLoading = true;
      _isError = false;
      notifyListeners();
    } else {
      // Jika data sudah ada di memori dan tidak ada perubahan parameter
      if (_publications.isNotEmpty) {
        _isInitialLoading = false;
        notifyListeners();
        return;
      }
      _isLoading = true;
      _isInitialLoading = true;
      _isError = false;
      notifyListeners();
    }

    await _loadData(
      page: 1,
      year: _selectedYear,
      keyword: _keyword,
      isRefresh: true,
    );
  }

  /// Memuat halaman berikutnya untuk pagination tak terbatas (infinite scroll).
  Future<void> fetchMorePublications() async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    await _loadData(
      page: _currentPage,
      year: _selectedYear,
      keyword: _keyword,
      isRefresh: false,
    );
  }

  Future<void> _loadData({
    required int page,
    String? year,
    String? keyword,
    required bool isRefresh,
  }) async {
    try {
      final url = ApiConfig.listUrl(
        model: 'publication',
        page: page,
        year: year,
        keyword: keyword,
      );
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['data'] != null &&
            jsonResponse['data'] is List &&
            (jsonResponse['data'] as List).length > 1) {
          final meta = jsonResponse['data'][0];
          final newItems = jsonResponse['data'][1] as List<dynamic>;

          if (isRefresh) {
            _publications.clear();
            _currentPage = 1;
          }

          if (newItems.isNotEmpty) {
            _publications.addAll(newItems);
            _currentPage++;
          }

          // Cek batas halaman berdasarkan metadata API BPS
          if (meta is Map<String, dynamic> && meta['pages'] != null) {
            final totalPages = int.tryParse(meta['pages'].toString()) ?? 1;
            final currentPageNum =
                int.tryParse(meta['page']?.toString() ?? '') ?? (_currentPage - 1);
            _hasMoreData = currentPageNum < totalPages;
          } else {
            _hasMoreData = newItems.length >= 10;
          }

          _isError = false;
        } else {
          if (isRefresh) {
            _publications.clear();
          }
          _hasMoreData = false;
          _isError = false;
        }
      } else {
        if (_publications.isEmpty) {
          _isError = true;
        }
        _hasMoreData = false;
      }
    } catch (e) {
      debugPrint('Error fetching publication page $page (year: $year, keyword: $keyword): $e');
      if (_publications.isEmpty) {
        _isError = true;
      }
      _hasMoreData = false;
    } finally {
      _isLoading = false;
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes dataset back to page 1 with active filters.
  Future<void> refreshPublications() async {
    await fetchPublications(
      isRefresh: true,
      year: _selectedYear,
      keyword: _keyword,
    );
  }
}
