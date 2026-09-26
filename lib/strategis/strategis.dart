import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:Dalem/components/bar.dart';
import 'package:Dalem/table/table.dart';
import 'package:Dalem/components/app_colors.dart';
import 'package:Dalem/components/bps_theme.dart';
import 'package:Dalem/config/api_config.dart';
import 'package:Dalem/components/state_widgets.dart';
import 'package:Dalem/services/bps_api_service.dart';
import 'package:Dalem/components/offline_banner_widget.dart';
import 'package:Dalem/utils/page_transitions.dart';

class Strategis extends StatefulWidget {
  final String title;
  final Color color;

  const Strategis({super.key, required this.title, required this.color});

  @override
  State<Strategis> createState() => _StrategisState();
}

class _StrategisState extends State<Strategis> {
  late Future<dynamic> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = BpsApiService.fetchJson(
      ApiConfig.listUrl(model: 'tablestatistic', keyword: 'strategis'),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar2(
        title: widget.title,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primaryNavy,
        backgroundColor: Colors.white,
        child: FutureBuilder<dynamic>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                },
              );
            } else if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  ErrorStateWidget(
                    title: 'Gagal Memuat Indikator Strategis',
                    message: 'Tidak dapat mengambil data indikator strategis dari server.',
                    onRetry: () {
                      setState(() {
                        _loadData();
                      });
                    },
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!['data'] == null || snapshot.data!['data'][1] == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [
                  EmptyStateWidget(
                    title: 'Data Strategis Kosong',
                    message: 'Belum ada indikator strategis yang tersedia.',
                  ),
                ],
              );
            } else {
              final isOffline = snapshot.data!['_is_offline'] == true;
              final items = snapshot.data!['data'][1] as List<dynamic>;
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: items.length + (isOffline ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isOffline && index == 0) {
                    return OfflineBannerWidget(
                      message: snapshot.data!['_offline_source'] == 'seed'
                          ? 'Server BPS tidak merespons. Menampilkan data bawaan Kabupaten Demak.'
                          : 'Server BPS tidak merespons. Menampilkan data tersimpan terakhir.',
                      onRefresh: _handleRefresh,
                    );
                  }
                  final itemIndex = isOffline ? index - 1 : index;
                  var item = items[itemIndex];
                  var decodedId = utf8.decode(base64.decode(item['id'].toString()));
                  var arrayId = decodedId.split('#');
                  var id = arrayId[0];

                  var titleParts = item['title'].split('Strategis] ');
                  var title = titleParts.length > 1 ? titleParts[1] : item['title'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildStatisticCategory(
                      title: title,
                      id: id,
                      onTap: () => Navigator.push(
                        context,
                        SmoothPageRoute(
                          child: DataTableScreen(
                            id: id,
                            title: title,
                            tableType: '2',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatisticCategory({
    required String id,
    required String title,
    required VoidCallback onTap,
  }) {
    final gradientColors = BpsTheme.current().cardGradient1;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFE2E8F0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: fetchDescription(id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Shimmer.fromColors(
                              baseColor: Colors.white10,
                              highlightColor: Colors.white24,
                              child: Container(
                                width: 140,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  ),
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return Text(
                              '-',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                            );
                          } else {
                            final data = snapshot.data ?? 'Tidak tersedia';
                            return Text(
                              data,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.secondaryGold,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String> fetchDescription(String id) async {
    try {
      final response =
          await BpsApiService.fetchJson(ApiConfig.dataUrl(varId: id));
      final data = response;
      final vervarData = (data["vervar"] as List<dynamic>?) ?? [];
      final varData = (data["var"] as List<dynamic>?) ?? [];
      final turvarData = (data["turvar"] as List<dynamic>?) ?? [];
      final dataContent = (data["datacontent"] is Map)
          ? (data["datacontent"] as Map)
          : <String, dynamic>{};
      final tahun = (data["tahun"] as List<dynamic>?) ?? [];
      final turTahun = (data["turtahun"] as List<dynamic>?) ?? [];

      if (varData.isEmpty || vervarData.isEmpty || tahun.isEmpty) {
        return 'Tidak tersedia';
      }

      final unit = varData.last["unit"]?.toString() ?? '';
      final turVarVal = turvarData.isNotEmpty ? turvarData.last["val"] : 0;
      final turTahunVal = turTahun.isNotEmpty ? turTahun.last["val"] : 0;
      final key =
          '${vervarData.last["val"]}${varData.last["val"]}$turVarVal${tahun.last["val"]}$turTahunVal';

      final rawVal = dataContent[key];
      if (rawVal == null || rawVal.toString() == '-') {
        return 'Tidak tersedia';
      }

      var resValue = "$rawVal $unit".replaceAll('.', ',');
      if (!resValue.contains(',')) {
        resValue = resValue.replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
      }

      var resTahun = tahun.last["label"]?.toString() ?? '';
      return '$resValue ($resTahun)';
    } catch (e) {
      return 'Tidak tersedia';
    }
  }
}
