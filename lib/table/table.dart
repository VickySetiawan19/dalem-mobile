import 'package:Dalem/components/bar.dart';
import 'package:Dalem/components/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:Dalem/components/app_colors.dart';
import 'package:Dalem/config/api_config.dart';
import 'package:Dalem/charts/chart_data_parser.dart';
import 'package:Dalem/charts/interactive_chart_view.dart';
import 'package:Dalem/engine/forecasting_chart_view.dart';
import 'package:Dalem/services/bps_api_service.dart';
import 'package:Dalem/components/offline_banner_widget.dart';

class DataTableScreen extends StatefulWidget {
  final String id;
  final String title;
  final String tableType;

  const DataTableScreen({
    super.key,
    required this.id,
    required this.title,
    required this.tableType,
  });

  @override
  DataTableScreenState createState() => DataTableScreenState();
}

class DataTableScreenState extends State<DataTableScreen> {
  late Future<Map<String, dynamic>> futureDataTable;
  late int selectedYear;

  /// View mode: 0 for Table (Tabel), 1 for Interactive Chart (Grafik)
  int _selectedViewMode = 0;

  /// For dynamic table (type 2): track which tahun indices are selected.
  /// null means "all available" (initial state before user interacts).
  Set<int>? _selectedDynamicYearIndices;

  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    final minYear = (currentYear - 3 < 2023) ? 2023 : (currentYear - 3);
    final years = <int>[];
    for (var y = currentYear; y >= minYear; y--) {
      years.add(y);
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    selectedYear = _availableYears.first;
    futureDataTable = fetchDataTable();
  }

  Future<Map<String, dynamic>> _fetchWithCache(String url) async {
    return BpsApiService.fetchJson(url);
  }

  Future<Map<String, dynamic>> fetchDataTable() async {
    final idParts = widget.id.split('#');
    final idOnly = idParts[0];

    if (widget.tableType == '1') {
      final url = ApiConfig.viewUrl(model: 'statictable', id: idOnly);
      return _fetchWithCache(url);
    } else if (widget.tableType == '2') {
      final url = ApiConfig.dataUrl(varId: idOnly);
      return _fetchWithCache(url);
    } else if (widget.tableType == '3') {
      final url = ApiConfig.simdasiUrl(idTabel: idOnly, tahun: selectedYear);
      try {
        final res = await _fetchWithCache(url);
        final rows = (res['data'] is List && (res['data'] as List).length > 1)
            ? ((res['data'][1] as Map?)?['data'] as List?)?.length ?? 0
            : 0;

        if (rows > 0) {
          return res;
        }

        // If currently selected year has no rows, check other available years
        for (var y in _availableYears) {
          if (y == selectedYear) continue;
          final fallbackUrl = ApiConfig.simdasiUrl(idTabel: idOnly, tahun: y);
          try {
            final fallbackRes = await _fetchWithCache(fallbackUrl);
            final fallbackRows = (fallbackRes['data'] is List && (fallbackRes['data'] as List).length > 1)
                ? ((fallbackRes['data'][1] as Map?)?['data'] as List?)?.length ?? 0
                : 0;
            if (fallbackRows > 0) {
              selectedYear = y;
              return fallbackRes;
            }
          } catch (_) {}
        }
        return res;
      } catch (_) {
        return _fetchWithCache(url);
      }
    } else {
      throw Exception('Tipe tabel tidak dikenali');
    }
  }

  Widget _buildViewModeToggle({bool hasForecasting = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          // 0: Tabel Data
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedViewMode != 0) {
                  setState(() {
                    _selectedViewMode = 0;
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: _selectedViewMode == 0
                      ? LinearGradient(
                          colors: [AppColors.primaryNavy, AppColors.primaryLight],
                        )
                      : null,
                  color: _selectedViewMode == 0 ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedViewMode == 0
                      ? [
                          BoxShadow(
                            color: AppColors.primaryNavy.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 15,
                      color: _selectedViewMode == 0 ? Colors.white : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tabel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: _selectedViewMode == 0 ? FontWeight.w700 : FontWeight.w600,
                        color: _selectedViewMode == 0 ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 1: Grafik Interaktif
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedViewMode != 1) {
                  setState(() {
                    _selectedViewMode = 1;
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: _selectedViewMode == 1
                      ? LinearGradient(
                          colors: [AppColors.primaryNavy, AppColors.primaryLight],
                        )
                      : null,
                  color: _selectedViewMode == 1 ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedViewMode == 1
                      ? [
                          BoxShadow(
                            color: AppColors.primaryNavy.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 15,
                      color: _selectedViewMode == 1 ? Colors.white : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Grafik',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: _selectedViewMode == 1 ? FontWeight.w700 : FontWeight.w600,
                        color: _selectedViewMode == 1 ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 2: Proyeksi Tren (Holt's DES)
          if (hasForecasting)
            Expanded(
              child: InkWell(
                onTap: () {
                  if (_selectedViewMode != 2) {
                    setState(() {
                      _selectedViewMode = 2;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: _selectedViewMode == 2
                        ? const LinearGradient(
                            colors: [Color(0xFFE8611A), Color(0xFFF97316)],
                          )
                        : null,
                    color: _selectedViewMode == 2 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _selectedViewMode == 2
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE8611A).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_graph_rounded,
                        size: 15,
                        color: _selectedViewMode == 2 ? Colors.white : const Color(0xFFE8611A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Proyeksi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: _selectedViewMode == 2 ? FontWeight.w700 : FontWeight.w600,
                          color: _selectedViewMode == 2 ? Colors.white : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primaryNavy),
              ),
              const SizedBox(width: 8),
              Text(
                'Pilih Tahun Data:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableYears.map((year) {
                final isSelected = selectedYear == year;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (selectedYear != year) {
                        setState(() {
                          selectedYear = year;
                          futureDataTable = _fetchWithCache(
                            ApiConfig.simdasiUrl(
                              idTabel: widget.id.split('#')[0],
                              tahun: year,
                            ),
                          );
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [AppColors.primaryNavy, AppColors.primaryLight],
                              )
                            : null,
                        color: isSelected ? null : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryNavy.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '$year',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build year selector for dynamic tables (tableType 2).
  /// [availableYears] is the list of tahun maps from the API response.
  Widget _buildDynamicYearSelector(List<Map<String, dynamic>> availableYears) {
    if (availableYears.isEmpty) return const SizedBox.shrink();

    // Default: all selected
    final selectedIndices = _selectedDynamicYearIndices ??
        Set<int>.from(List.generate(availableYears.length, (i) => i));

    final isSingleYear = availableYears.length == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primaryNavy),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilih Tahun Data:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (!isSingleYear)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selectedIndices.length == availableYears.length) {
                        // If all selected, select only the last one (most recent)
                        _selectedDynamicYearIndices = {availableYears.length - 1};
                      } else {
                        // Select all
                        _selectedDynamicYearIndices = Set<int>.from(
                            List.generate(availableYears.length, (i) => i));
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selectedIndices.length == availableYears.length
                          ? AppColors.primaryNavy.withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      selectedIndices.length == availableYears.length ? 'Semua ✓' : 'Pilih Semua',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selectedIndices.length == availableYears.length
                            ? AppColors.primaryNavy
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(availableYears.length, (index) {
              final yearItem = availableYears[index];
              final label = yearItem['label']?.toString() ?? '';
              final isSelected = selectedIndices.contains(index);
              return InkWell(
                onTap: isSingleYear
                    ? null
                    : () {
                        setState(() {
                          final newSet = Set<int>.from(selectedIndices);
                          if (isSelected) {
                            if (newSet.length > 1) {
                              newSet.remove(index);
                            }
                          } else {
                            newSet.add(index);
                          }
                          _selectedDynamicYearIndices = newSet;
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [AppColors.primaryNavy, AppColors.primaryLight],
                          )
                        : null,
                    color: isSelected ? null : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryNavy.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Build year badge for static tables (tableType 1).
  Widget _buildStaticYearBadge(String title, String? updtDate) {
    // Extract 4-digit years from title or update date
    final yearMatches = RegExp(r'\b(20\d{2})\b').allMatches(title).map((m) => m.group(1)!).toSet().toList();
    if (yearMatches.isEmpty && updtDate != null) {
      final updtMatch = RegExp(r'\b(20\d{2})\b').firstMatch(updtDate);
      if (updtMatch != null) {
        yearMatches.add(updtMatch.group(1)!);
      }
    }
    if (yearMatches.isEmpty) {
      yearMatches.add('${DateTime.now().year}');
    }
    yearMatches.sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primaryNavy),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tahun Data Tersedia:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tabel Statis',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: yearMatches.map((yearStr) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryNavy, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      yearStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Helper to extract tahun from API data and build the year selector widget list.
  List<Widget> _buildDynamicYearSelectorFromData(Map<String, dynamic> data) {
    final rawTahun = (data['tahun'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final activeTahun = _getActiveTahun(rawTahun);
    if (activeTahun.isEmpty) return [];
    return [_buildDynamicYearSelector(activeTahun)];
  }

  /// Get filtered tahun for dynamic tables based on user selection (defaults to activeTahun >= 2023).
  List<Map<String, dynamic>> _getFilteredDynamicTahun(Map<String, dynamic> data) {
    final rawTahun = (data['tahun'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final activeTahun = _getActiveTahun(rawTahun);
    if (_selectedDynamicYearIndices != null && activeTahun.isNotEmpty) {
      final filtered = _selectedDynamicYearIndices!
          .where((i) => i < activeTahun.length)
          .map((i) => activeTahun[i])
          .toList();
      return filtered.isNotEmpty ? filtered : activeTahun;
    }
    return activeTahun;
  }

  String _colorToHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  String _decodeHtml(String html) {
    return html
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }

  List<Map<String, dynamic>> _getActiveTahun(List<Map<String, dynamic>> rawTahun) {
    if (rawTahun.isEmpty) return [];
    final currentYear = DateTime.now().year;
    final minYear = (currentYear - 3 < 2023) ? 2023 : (currentYear - 3);

    // 1. If table has data for recent years (>= minYear e.g. 2023, 2024, 2025, 2026), filter to only those
    final recentYears = rawTahun.where((t) {
      final label = t['label']?.toString() ?? '';
      final yearNum = int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), ''));
      if (yearNum != null) {
        return yearNum >= minYear;
      }
      return false;
    }).toList();

    if (recentYears.isNotEmpty) {
      return recentYears;
    }

    // 2. If table is historical only (data exists before 2023), show its available years (up to the last 5 years)
    if (rawTahun.length > 5) {
      return rawTahun.sublist(rawTahun.length - 5);
    }
    return rawTahun;
  }

  String generateSimdasiHtmlTable(Map<String, dynamic> tableObj) {
    final headerBg = _colorToHex(AppColors.primaryNavy);
    final headerBorder = _colorToHex(AppColors.primaryDark);

    final rawKolom = tableObj['kolom'];
    final rawData = tableObj['data'];

    if (rawKolom is! Map || rawData is! List || rawData.isEmpty) {
      return '<p style="text-align:center; padding: 20px; color: #64748B;">Data tabel tidak tersedia.</p>';
    }

    final Map<String, dynamic> kolomMap = rawKolom.cast<String, dynamic>();
    final List<dynamic> rowsList = rawData;

    var html = '''
    <table border="1" style="width: 100%; border-collapse: collapse; font-family: 'Plus Jakarta Sans', sans-serif; font-size: 12px; border: 1px solid #E2E8F0;">
      <thead>
        <tr style="background-color: $headerBg; color: white;">
          <th style="border: 1px solid $headerBorder; padding: 10px 12px; text-align: center; font-weight: 700;">Wilayah / Kecamatan</th>
    ''';

    for (var entry in kolomMap.entries) {
      final colData = entry.value as Map<String, dynamic>? ?? {};
      final colName = colData['nama_variabel']?.toString() ?? entry.key;
      final rawSatuan = colData['satuan']?.toString() ?? '';
      final rawMultiplier = colData['unit_multiplier_desc']?.toString() ?? '';
      final rawUnit = colData['unit']?.toString() ?? '';

      String unitText = '';
      if (rawMultiplier.isNotEmpty && rawMultiplier != 'null' && rawMultiplier != '-') {
        if (rawSatuan.isNotEmpty && rawSatuan != 'null' && rawSatuan != '-') {
          unitText = '$rawMultiplier $rawSatuan';
        } else {
          unitText = rawMultiplier;
        }
      } else if (rawSatuan.isNotEmpty && rawSatuan != 'null' && rawSatuan != '-') {
        unitText = rawSatuan;
      } else if (rawUnit.isNotEmpty && rawUnit != 'null' && rawUnit != '-') {
        unitText = rawUnit;
      }

      String satuan = '';
      if (unitText.isNotEmpty) {
        if (!colName.toLowerCase().contains(unitText.toLowerCase())) {
          satuan = ' ($unitText)';
        }
      }

      html +=
          '<th style="border: 1px solid $headerBorder; padding: 10px 12px; text-align: center; font-weight: 700;">$colName$satuan</th>';
    }

    html += '</tr></thead><tbody>';

    int rowIndex = 0;
    for (var row in rowsList) {
      if (row is! Map) continue;
      final bg = (rowIndex % 2 == 0) ? '#FFFFFF' : '#F8FAFC';
      final label = row['label']?.toString() ?? '';
      final variables = (row['variables'] as Map?)?.cast<String, dynamic>() ?? {};

      html += '<tr style="background-color: $bg;">';
      html +=
          '<td style="border: 1px solid #E2E8F0; padding: 8px 12px; text-align: left; font-weight: 500; color: #1E293B;">$label</td>';

      for (var colKey in kolomMap.keys) {
        final varObj = variables[colKey];
        String val = '-';
        if (varObj is Map && varObj['value'] != null) {
          val = varObj['value'].toString();
        } else if (varObj != null) {
          val = varObj.toString();
        }
        html +=
            '<td style="border: 1px solid #E2E8F0; padding: 8px 12px; text-align: right; font-weight: 600; color: #0F172A;">$val</td>';
      }

      html += '</tr>';
      rowIndex++;
    }

    html += '</tbody></table>';

    final sumber = tableObj['sumber']?.toString();
    if (sumber != null && sumber.isNotEmpty) {
      final decodedSumber = _decodeHtml(sumber);
      html += '<div style="margin-top: 12px; font-size: 11px; color: #64748B;">$decodedSumber</div>';
    }

    return html;
  }

  String generateSimdasiCsv(Map<String, dynamic> tableObj) {
    final rawKolom = tableObj['kolom'];
    final rawData = tableObj['data'];

    if (rawKolom is! Map || rawData is! List || rawData.isEmpty) {
      return '';
    }

    final Map<String, dynamic> kolomMap = rawKolom.cast<String, dynamic>();
    final List<dynamic> rowsList = rawData;

    List<List<String>> csvData = [];

    // Header
    List<String> header = ['Wilayah / Kecamatan'];
    for (var entry in kolomMap.entries) {
      final colData = entry.value as Map<String, dynamic>? ?? {};
      final colName = colData['nama_variabel']?.toString() ?? entry.key;
      final rawSatuan = colData['satuan']?.toString() ?? '';
      final rawMultiplier = colData['unit_multiplier_desc']?.toString() ?? '';
      final rawUnit = colData['unit']?.toString() ?? '';

      String unitText = '';
      if (rawMultiplier.isNotEmpty && rawMultiplier != 'null' && rawMultiplier != '-') {
        if (rawSatuan.isNotEmpty && rawSatuan != 'null' && rawSatuan != '-') {
          unitText = '$rawMultiplier $rawSatuan';
        } else {
          unitText = rawMultiplier;
        }
      } else if (rawSatuan.isNotEmpty && rawSatuan != 'null' && rawSatuan != '-') {
        unitText = rawSatuan;
      } else if (rawUnit.isNotEmpty && rawUnit != 'null' && rawUnit != '-') {
        unitText = rawUnit;
      }

      String satuan = '';
      if (unitText.isNotEmpty) {
        if (!colName.toLowerCase().contains(unitText.toLowerCase())) {
          satuan = ' ($unitText)';
        }
      }
      header.add('$colName$satuan');
    }
    csvData.add(header);

    // Rows
    for (var row in rowsList) {
      if (row is! Map) continue;
      final label = row['label']?.toString() ?? '';
      final variables = (row['variables'] as Map?)?.cast<String, dynamic>() ?? {};
      List<String> rowData = [label];

      for (var colKey in kolomMap.keys) {
        final varObj = variables[colKey];
        String val = '-';
        if (varObj is Map && varObj['value'] != null) {
          val = varObj['value'].toString();
        } else if (varObj != null) {
          val = varObj.toString();
        }
        rowData.add(val);
      }
      csvData.add(rowData);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  String generateHtmlTable(Map<String, dynamic> data, {List<Map<String, dynamic>>? filteredTahun}) {
    final headerBg = _colorToHex(AppColors.primaryNavy);
    final headerBorder = _colorToHex(AppColors.primaryDark);

    final varData =
        (data["var"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final vervarData =
        (data["vervar"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final turvarData =
        (data["turvar"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final dataContent =
        (data["datacontent"] as Map?)?.cast<String, dynamic>() ?? {};
    final rawTahun =
        (data["tahun"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final tahun = filteredTahun ?? _getActiveTahun(rawTahun);
    final turTahun =
        (data["turtahun"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    if (vervarData.isEmpty || tahun.isEmpty) {
      return '<p style="text-align:center; padding: 20px; color: #64748B;">Data tabel tidak tersedia untuk rentang tahun ini.</p>';
    }

    final turTahunVal = turTahun.isNotEmpty ? turTahun[0]['val'] : 0;
    final vervarLabel = data['labelvervar']?.toString() ?? 'Kategori';

    var html = '''
    <table border="1" style="width: 100%; border-collapse: collapse; font-family: 'Plus Jakarta Sans', sans-serif; font-size: 12px; border: 1px solid #E2E8F0;">
      <thead>
        <tr style="background-color: $headerBg; color: white;">
          <th rowspan="3" style="border: 1px solid $headerBorder; padding: 10px 12px; text-align: center; font-weight: 700;">$vervarLabel</th>
    ''';

    for (var varItem in varData) {
      final colSpan = tahun.length * (turvarData.isNotEmpty ? turvarData.length : 1);
      final label = varItem['label']?.toString() ?? '';
      final rawUnit = varItem['unit']?.toString() ?? varItem['satuan']?.toString() ?? '';
      String unitStr = '';
      if (rawUnit.isNotEmpty &&
          rawUnit != 'null' &&
          rawUnit != '-' &&
          rawUnit.toLowerCase() != 'tidak ada') {
        if (!label.toLowerCase().contains(rawUnit.toLowerCase())) {
          unitStr = ' ($rawUnit)';
        }
      }
      html +=
          '<th colspan="$colSpan" style="border: 1px solid $headerBorder; padding: 10px 12px; text-align: center; font-weight: 700;">$label$unitStr</th>';
    }
    html +=
        '</tr><tr style="background-color: $headerBg; color: white;">';

    for (var _ in varData) {
      if (turvarData.isNotEmpty) {
        for (var element in turvarData) {
          html +=
              '<th colspan="${tahun.length}" style="border: 1px solid $headerBorder; padding: 10px 12px; text-align: center; font-weight: 700;">${element['label'] == 'Tidak Ada' || element['label'] == 'Tidak ada' ? 'Tahun' : element['label']}</th>';
        }
      } else {
        html +=
            '<th colspan="${tahun.length}" style="border: 1px solid $headerBorder; padding: 10px 12px; text-align: center; font-weight: 700;">Tahun</th>';
      }
    }

    html +=
        '</tr><tr style="background-color: $headerBg; color: white;">';

    for (var _ in varData) {
      final tVars = turvarData.isNotEmpty ? turvarData : [{'val': 0}];
      for (var _ in tVars) {
        for (var element in tahun) {
          html +=
              '<th style="border: 1px solid $headerBorder; padding: 10px 12px; text-align: center; font-weight: 700;">${element['label']}</th>';
        }
      }
    }

    html += '</tr></thead><tbody>';

    int rowIndex = 0;
    for (var vervar in vervarData) {
      final bg = (rowIndex % 2 == 0) ? '#FFFFFF' : '#F8FAFC';
      html += '<tr style="background-color: $bg;">';
      html +=
          '<td style="border: 1px solid #E2E8F0; padding: 8px 12px; text-align: left; font-weight: 500; color: #1E293B;">${vervar['label']}</td>';
      for (var varItem in varData) {
        final tVars = turvarData.isNotEmpty ? turvarData : [{'val': 0}];
        for (var turvar in tVars) {
          for (var tahunItem in tahun) {
            final key =
                "${vervar["val"]}${varItem["val"]}${turvar["val"]}${tahunItem['val']}$turTahunVal";
            String value = dataContent[key]?.toString() ?? '-';
            if (value != '-') {
              value = value.replaceAll('.', ',');
              value = value.replaceAllMapped(
                  RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
            }
            html +=
                '<td style="border: 1px solid #E2E8F0; padding: 8px 12px; text-align: right; font-weight: 600; color: #0F172A;">$value</td>';
          }
        }
      }
      html += '</tr>';
      rowIndex++;
    }

    html += '</tbody></table>';

    return html;
  }

  String generateCsv(Map<String, dynamic> data, {List<Map<String, dynamic>>? filteredTahun}) {
    final varData =
        (data["var"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final vervarData =
        (data["vervar"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final turvarData =
        (data["turvar"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final dataContent =
        (data["datacontent"] as Map?)?.cast<String, dynamic>() ?? {};
    final rawTahun =
        (data["tahun"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final tahun = filteredTahun ?? _getActiveTahun(rawTahun);
    final turTahun =
        (data["turtahun"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    final turTahunVal = turTahun.isNotEmpty ? turTahun[0]['val'] : 0;
    List<List<String>> csvData = [];

    // Header 1
    List<String> header1 = [''];
    for (var varItem in varData) {
      final count = tahun.length * (turvarData.isNotEmpty ? turvarData.length : 1);
      final label = varItem['label']?.toString() ?? '';
      final rawUnit = varItem['unit']?.toString() ?? varItem['satuan']?.toString() ?? '';
      String unitStr = '';
      if (rawUnit.isNotEmpty &&
          rawUnit != 'null' &&
          rawUnit != '-' &&
          rawUnit.toLowerCase() != 'tidak ada') {
        if (!label.toLowerCase().contains(rawUnit.toLowerCase())) {
          unitStr = ' ($rawUnit)';
        }
      }
      header1.addAll(List.filled(count, '$label$unitStr'));
    }
    csvData.add(header1);

    // Header 2
    List<String> header2 = [data['labelvervar']?.toString() ?? 'Kategori'];
    for (var _ in varData) {
      if (turvarData.isNotEmpty) {
        for (var element in turvarData) {
          header2.addAll(List.filled(tahun.length,
              (element['label'] == 'Tidak Ada' || element['label'] == 'Tidak ada') ? 'Tahun' : element['label']));
        }
      } else {
        header2.addAll(List.filled(tahun.length, 'Tahun'));
      }
    }
    csvData.add(header2);

    // Header 3
    List<String> header3 = [''];
    for (var _ in varData) {
      final tVars = turvarData.isNotEmpty ? turvarData : [{'val': 0}];
      for (var _ in tVars) {
        for (var tahunItem in tahun) {
          header3.add(tahunItem['label']?.toString() ?? '');
        }
      }
    }
    csvData.add(header3);

    // Rows
    for (var vervar in vervarData) {
      List<String> row = [vervar['label']?.toString() ?? ''];
      for (var varItem in varData) {
        final tVars = turvarData.isNotEmpty ? turvarData : [{'val': 0}];
        for (var turvar in tVars) {
          for (var tahunItem in tahun) {
            final key =
                "${vervar["val"]}${varItem["val"]}${turvar["val"]}${tahunItem['val']}$turTahunVal";
            row.add(dataContent[key]?.toString() ?? '-');
          }
        }
      }
      csvData.add(row);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  Future<void> downloadCsv(String csv) async {
    try {
      final directory = Directory('/storage/emulated/0/Download/Dalem');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final safeId = widget.id.replaceAll('#', '_');
      final path = '${directory.path}/${widget.title}_$safeId.xls';
      final file = File(path);
      await file.writeAsString(csv);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                  const SizedBox(width: 8),
                  Text('Unduhan Berhasil', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text('File tabel berhasil disimpan di:\n$path', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar2(
        title: 'Detail Tabel',
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureDataTable,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                      height: 30,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError ||
              snapshot.data is! Map<String, dynamic>) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.table_rows_rounded,
                        size: 64,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tabel Data Belum Tersedia',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Data untuk tabel ini belum tersedia di server BPS.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          futureDataTable = fetchDataTable();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            final data = snapshot.data!;

            // Check availability for static, SIMDASI, and dynamic tables
            bool isDataAvailable = true;
            String tableHtml = '';
            String? staticExcelUrl;
            Map<String, dynamic>? simdasiTableObj;

            if (widget.tableType == '1') {
              // Static table
              final staticData = data['data'];
              if (staticData != null && staticData is Map && staticData['table'] != null) {
                tableHtml = _decodeHtml(staticData['table'].toString());
                staticExcelUrl = staticData['excel']?.toString();
              } else {
                isDataAvailable = false;
              }
            } else if (widget.tableType == '3') {
              // SIMDASI table (interoperabilitas)
              if (data['data'] is List && (data['data'] as List).length > 1) {
                final tableObj = data['data'][1];
                if (tableObj is Map &&
                    tableObj['data'] is List &&
                    (tableObj['data'] as List).isNotEmpty) {
                  simdasiTableObj = tableObj.cast<String, dynamic>();
                  tableHtml = generateSimdasiHtmlTable(simdasiTableObj);
                } else {
                  isDataAvailable = false;
                }
              } else {
                isDataAvailable = false;
              }
            } else {
              // Dynamic table (tableType 2)
              final availability = data['data-availability']?.toString();
              final tahun = data['tahun'] as List<dynamic>?;
              final dataContent = data['datacontent'];
              if (availability == 'list-not-available' ||
                  availability == 'not-available' ||
                  tahun == null ||
                  tahun.isEmpty ||
                  (dataContent is List && dataContent.isEmpty) ||
                  (dataContent is Map && dataContent.isEmpty)) {
                isDataAvailable = false;
              } else {
                tableHtml = generateHtmlTable(data, filteredTahun: _getFilteredDynamicTahun(data));
              }
            }

            if (!isDataAvailable || tableHtml.isEmpty) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (widget.tableType == '3') _buildYearSelector(),
                  if (widget.tableType == '2') ..._buildDynamicYearSelectorFromData(data),
                  if (widget.tableType == '1') _buildStaticYearBadge(widget.title, (data['data'] as Map?)?['updt_date']?.toString()),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.table_rows_rounded,
                        size: 64,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tabel Data Belum Tersedia',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.tableType == '3'
                          ? 'Data statistik untuk tahun $selectedYear belum tersedia di BPS Kabupaten Demak. Silakan pilih tahun lain di atas.'
                          : 'Data statistik untuk tabel ini belum tersedia dari BPS Kabupaten Demak.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Parse series for interactive chart visualization
            List<ChartSeries> chartSeries = [];
            if (widget.tableType == '3' && simdasiTableObj != null) {
              chartSeries = ChartDataParser.parseSimdasi(simdasiTableObj);
            } else if (widget.tableType == '2') {
              chartSeries = ChartDataParser.parseDynamic(
                data,
                filteredTahun: _getFilteredDynamicTahun(data),
              );
            } else if (widget.tableType == '1' && tableHtml.isNotEmpty) {
              chartSeries = ChartDataParser.parseStaticHtml(tableHtml);
            }

            final bool hasChartData = chartSeries.isNotEmpty;
            final bool hasForecastingData = chartSeries.any((s) {
              final yearCount = s.points.where((p) => RegExp(r'\b(19|20\d{2})\b').hasMatch(p.label)).length;
              return yearCount >= 2;
            });
            final activeViewMode = hasChartData ? _selectedViewMode : 0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['_is_offline'] == true)
                    OfflineBannerWidget(
                      message: data['_offline_source'] == 'seed'
                          ? 'Server BPS tidak merespons. Menampilkan data cadangan Kabupaten Demak.'
                          : 'Server BPS tidak merespons. Menampilkan data tersimpan terakhir.',
                      onRefresh: () {
                        setState(() {
                          futureDataTable = fetchDataTable();
                        });
                      },
                    ),

                  // 1. View Mode Switcher: [ Tabel ] | [ Grafik ] | [ Proyeksi (AI) ]
                  // Only display toggle if valid chart series exists (Smart Adaptive UI)
                  if (hasChartData) _buildViewModeToggle(hasForecasting: hasForecastingData),

                  if (activeViewMode != 2 && widget.tableType == '3') _buildYearSelector(),
                  if (activeViewMode != 2 && widget.tableType == '2') ..._buildDynamicYearSelectorFromData(data),
                  if (activeViewMode != 2 && widget.tableType == '1') _buildStaticYearBadge(widget.title, (data['data'] as Map?)?['updt_date']?.toString()),

                  if (activeViewMode == 2 && hasForecastingData) ...[
                    ForecastingChartView(
                      title: simdasiTableObj?['judul_tabel']?.toString() ?? widget.title,
                      seriesList: chartSeries.where((s) {
                        final yearCount = s.points.where((p) => RegExp(r'\b(19|20\d{2})\b').hasMatch(p.label)).length;
                        return yearCount >= 2;
                      }).toList(),
                      subtitle: widget.tableType == '3'
                          ? 'Model Holt\'s Double Exponential Smoothing • BPS Kab. Demak'
                          : 'Proyeksi Deret Waktu (Time-Series) BPS Demak',
                    ),
                  ] else if (activeViewMode == 1 && hasChartData) ...[
                    InteractiveChartView(
                      title: simdasiTableObj?['judul_tabel']?.toString() ?? widget.title,
                      seriesList: chartSeries,
                      subtitle: widget.tableType == '3'
                          ? 'Tahun Data: $selectedYear • BPS Kab. Demak'
                          : 'Sumber Data BPS Kabupaten Demak',
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            simdasiTableObj?['judul_tabel']?.toString() ?? widget.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: HtmlWidget(tableHtml),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Download button (Table view mode only)
                  if (activeViewMode == 0) ...[
                    if (widget.tableType == '1' && staticExcelUrl != null && staticExcelUrl.isNotEmpty)
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryNavy, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNavy.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              final uri = Uri.parse(staticExcelUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tidak dapat membuka link unduhan Excel.')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.download_rounded, color: Colors.white),
                            label: Text(
                              'Unduh Tabel (.xls)',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (widget.tableType == '3' && simdasiTableObj != null)
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryNavy, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNavy.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              final csv = generateSimdasiCsv(simdasiTableObj!);
                              await downloadCsv(csv);
                            },
                            icon: const Icon(Icons.download_rounded, color: Colors.white),
                            label: Text(
                              'Unduh Tabel (.xls)',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (widget.tableType == '2' &&
                        data["datacontent"] != null &&
                        (data["datacontent"] is Map && (data["datacontent"] as Map).isNotEmpty))
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryNavy, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryNavy.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              final csv = generateCsv(data, filteredTahun: _getFilteredDynamicTahun(data));
                              await downloadCsv(csv);
                            },
                            icon: const Icon(Icons.download_rounded, color: Colors.white),
                            label: Text(
                              'Unduh Tabel (.xls)',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        launchUrl(Uri.parse(
                            'https://ppid.bps.go.id/app/konten/3321/Profil-BPS.html?_gl=1*9iomf9*_ga*ODk0Njg5NDUyLjE3MzMzNjI0NDI.*_ga_XXTTVXWHDB*MTc0MDM2MTk3My40My4xLjE3NDAzNjIyODcuMC4wLjA.'));
                      },
                      child: Text(
                        'Hak Cipta © ${DateTime.now().year} Badan Pusat Statistik Kabupaten Demak',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}
