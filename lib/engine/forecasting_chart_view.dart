import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Dalem/components/app_colors.dart';
import 'package:Dalem/charts/chart_data_parser.dart';
import 'package:Dalem/engine/forecasting_models.dart';
import 'package:Dalem/engine/forecasting_engine.dart';

class ForecastingChartView extends StatefulWidget {
  final String title;
  final List<ChartSeries> seriesList;
  final String? subtitle;

  const ForecastingChartView({
    super.key,
    required this.title,
    required this.seriesList,
    this.subtitle,
  });

  @override
  State<ForecastingChartView> createState() => _ForecastingChartViewState();
}

class _ForecastingChartViewState extends State<ForecastingChartView> {
  int _selectedSeriesIndex = 0;
  bool _isAutoOptimized = true;
  double _manualAlpha = 0.30;
  double _manualBeta = 0.10;
  final int _horizon = 2; // Forecast 2 years ahead
  bool _showDetailsTable = false;

  ChartSeries? get _activeSeries {
    if (widget.seriesList.isEmpty) return null;
    if (_selectedSeriesIndex >= widget.seriesList.length) {
      return widget.seriesList.first;
    }
    return widget.seriesList[_selectedSeriesIndex];
  }

  /// Convert ChartSeries points into sorted TimeSeriesPoints for the engine.
  List<TimeSeriesPoint> _extractTimeSeries(ChartSeries series) {
    final list = <TimeSeriesPoint>[];
    for (var p in series.points) {
      final cleanLabel = p.label.trim();
      final yearMatch = RegExp(r'\b(19|20\d{2})\b').firstMatch(cleanLabel);
      if (yearMatch != null) {
        final year = int.tryParse(yearMatch.group(0)!);
        if (year != null && !p.value.isNaN && !p.value.isInfinite) {
          list.add(TimeSeriesPoint(
            period: year,
            value: p.value,
            label: cleanLabel,
          ));
        }
      }
    }
    // Sort ascending by year
    list.sort((a, b) => a.period.compareTo(b.period));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final series = _activeSeries;
    if (series == null) {
      return _buildEmptyState('Tidak ada data series yang tersedia.');
    }

    final timeSeries = _extractTimeSeries(series);
    if (timeSeries.length < 2) {
      return _buildEmptyState(
        'Data historis tahunan belum cukup untuk peramalan time-series (minimal 2 titik tahun).',
      );
    }

    // Run Forecasting Engine
    final ForecastResult result = ForecastingEngine.runDoubleExponentialSmoothing(
      timeSeries,
      alpha: _isAutoOptimized ? null : _manualAlpha,
      beta: _isAutoOptimized ? null : _manualBeta,
      horizon: _horizon,
      indicatorTitle: series.name.isNotEmpty ? series.name : widget.title,
      unit: series.unit,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Academic & Engine Badge
          _buildHeader(result),
          const SizedBox(height: 16),

          // Series Selector Chips (if multi-series)
          if (widget.seriesList.length > 1) ...[
            _buildSeriesSelector(),
            const SizedBox(height: 16),
          ],

          // Key Metrics Summary Cards (KPIs)
          _buildKpiCards(result),
          const SizedBox(height: 20),

          // Main Forecast Chart (fl_chart)
          _buildLineChart(result),
          const SizedBox(height: 16),

          // Chart Legend
          _buildChartLegend(result),
          const SizedBox(height: 20),

          // Interactive Parameter Tuning Panel (Alpha & Beta Controls)
          _buildParameterControl(result),
          const SizedBox(height: 20),

          // Narrative Insight Card
          _buildNarrativeCard(result),
          const SizedBox(height: 16),

          // Toggle & Historical Fit Table (Evaluasi Model & Uji Akurasi)
          _buildTableToggle(),
          if (_showDetailsTable) ...[
            const SizedBox(height: 12),
            _buildHistoricalTable(result),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ForecastResult result) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D3D85), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_graph_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      'Holt\'s DES Method',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'AI Proyeksi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeriesSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(widget.seriesList.length, (index) {
          final isSelected = index == _selectedSeriesIndex;
          final s = widget.seriesList[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              selected: isSelected,
              label: Text(s.name),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
              backgroundColor: const Color(0xFFF1F5F9),
              selectedColor: AppColors.primaryNavy,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppColors.primaryNavy : const Color(0xFFCBD5E1),
                ),
              ),
              onSelected: (val) {
                setState(() {
                  _selectedSeriesIndex = index;
                });
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKpiCards(ForecastResult result) {
    final nextForecast = result.forecasts.isNotEmpty ? result.forecasts.first : null;
    final lastActual = result.historicalData.isNotEmpty ? result.historicalData.last : null;
    final delta = (nextForecast != null && lastActual != null)
        ? nextForecast.value - lastActual.value
        : 0.0;
    final isPositiveDelta = delta >= 0;
    final deltaSign = isPositiveDelta ? '+' : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Card 1: Hasil Proyeksi Tahun Depan
            Container(
              width: cardWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Proyeksi ${nextForecast?.period ?? '-'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPositiveDelta
                              ? const Color(0xFF065F46).withValues(alpha: 0.5)
                              : const Color(0xFF991B1B).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$deltaSign${delta.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPositiveDelta ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            nextForecast != null
                                ? ChartDataParser.formatIndonesianNumber(nextForecast.value)
                                : '-',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (result.unit.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          result.unit,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aktual ${lastActual?.period}: ${lastActual != null ? ChartDataParser.formatIndonesianNumber(lastActual.value) : '-'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Card 2: Akurasi / Error Model (MAPE)
            Container(
              width: cardWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Akurasi Model',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: result.metrics.mape < 10.0
                              ? const Color(0xFFECFDF5)
                              : (result.metrics.mape <= 20.0
                                  ? const Color(0xFFEFF6FF)
                                  : (result.metrics.mape <= 50.0
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFFEE2E2))),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          result.metrics.mape < 10.0
                              ? 'Sangat Baik'
                              : (result.metrics.mape <= 20.0
                                  ? 'Baik'
                                  : (result.metrics.mape <= 50.0 ? 'Wajar' : 'Fluktuatif')),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: result.metrics.mape < 10.0
                                ? const Color(0xFF059669)
                                : (result.metrics.mape <= 20.0
                                    ? const Color(0xFF2563EB)
                                    : (result.metrics.mape <= 50.0
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFDC2626))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            result.metrics.mape > 100.0
                                ? '${result.metrics.mape.toStringAsFixed(1)}%'
                                : '${result.metrics.accuracyScore.toStringAsFixed(1)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        result.metrics.mape > 100.0 ? 'MAPE' : 'Skor',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MAPE: ${result.metrics.mape}% (Lewis, 1982)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineChart(ForecastResult result) {
    final hist = result.historicalData;
    final fore = result.forecasts;

    // Collect all X points
    final allPoints = <FlSpot>[];
    for (int i = 0; i < hist.length; i++) {
      allPoints.add(FlSpot(i.toDouble(), hist[i].value));
    }

    // Projections start from the last historical point
    final forecastSpots = <FlSpot>[
      FlSpot((hist.length - 1).toDouble(), hist.last.value),
    ];
    for (int i = 0; i < fore.length; i++) {
      forecastSpots.add(FlSpot((hist.length + i).toDouble(), fore[i].value));
    }

    // Min and Max Y for scaling (handles negative values properly)
    final allValues = [
      ...hist.map((p) => p.value),
      ...fore.map((p) => p.value),
    ];
    final double dataMin = allValues.reduce(min);
    final double dataMax = allValues.reduce(max);
    final double rawRange = (dataMax - dataMin).abs() <= 0.0001 ? 10.0 : (dataMax - dataMin).abs();

    // Add headroom so top and bottom points don't touch the edges
    final double paddedMin = (dataMin < 0)
        ? (dataMin - rawRange * 0.15)
        : (dataMin - rawRange * 0.15 > 0 ? dataMin - rawRange * 0.15 : 0.0);
    final double paddedMax = dataMax + rawRange * 0.15;

    final double yRange = (paddedMax - paddedMin) <= 0 ? 10.0 : (paddedMax - paddedMin);
    final double yInterval = ChartDataParser.calculateNiceYInterval(yRange, targetTicks: 4);

    // Align finalMinY and finalMaxY strictly to exact integer multiples of yInterval!
    final double finalMinY = (paddedMin / yInterval).floorToDouble() * yInterval;
    double finalMaxY = (paddedMax / yInterval).ceilToDouble() * yInterval;
    if (finalMaxY <= finalMinY) {
      finalMaxY = finalMinY + (yInterval * 4);
    }
    final int yDecimals = (yInterval < 0.1) ? 2 : (yInterval < 1.0 ? 1 : 0);
    final double leftReservedSize = (finalMaxY.abs() >= 10000 || finalMinY.abs() >= 10000)
        ? 52.0
        : (finalMaxY.abs() >= 100 || finalMinY.abs() >= 100 ? 44.0 : 38.0);

    return AspectRatio(
      aspectRatio: 1.45,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (val) {
              final isZero = val.abs() < (yInterval * 0.05);
              if (isZero && finalMinY < 0) {
                // Prominent baseline at Y = 0
                return const FlLine(
                  color: Color(0xFF94A3B8),
                  strokeWidth: 1.5,
                  dashArray: [4, 4],
                );
              }
              return const FlLine(
                color: Color(0xFFF1F5F9),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < hist.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${hist[idx].period}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    );
                  } else if (idx >= hist.length && idx < hist.length + fore.length) {
                    final foreIdx = idx - hist.length;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '\'${fore[foreIdx].period.toString().substring(2)}*',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE8611A), // Orange forecast accent
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: leftReservedSize,
                interval: yInterval,
                getTitlesWidget: (val, meta) {
                  // Only render ticks that are aligned to multiples of yInterval
                  final remainder = (val - finalMinY).abs() % yInterval;
                  final isNearTick = remainder < (yInterval * 0.05) ||
                      (yInterval - remainder).abs() < (yInterval * 0.05);
                  if (!isNearTick) {
                    return const SizedBox.shrink();
                  }

                  // Avoid collision near the top if fl_chart draws an extra meta.max tick
                  if ((val - meta.max).abs() < (yInterval * 0.3) && (val - meta.max).abs() > 0.0001) {
                    return const SizedBox.shrink();
                  }

                  final isZero = val.abs() < (yInterval * 0.01);
                  return Text(
                    ChartDataParser.formatIndonesianNumber(val, maxDecimals: yDecimals),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: (isZero && finalMinY < 0)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: (isZero && finalMinY < 0)
                          ? const Color(0xFF334155)
                          : const Color(0xFF94A3B8),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (hist.length + fore.length - 1).toDouble(),
          minY: finalMinY,
          maxY: finalMaxY,
          lineBarsData: [
            // 1. Historical Data Line (Solid Navy)
            LineChartBarData(
              spots: allPoints,
              isCurved: true,
              curveSmoothness: 0.25,
              color: const Color(0xFF0D3D85),
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: const Color(0xFF0D3D85),
                ),
              ),
              belowBarData: BarAreaData(
                show: finalMinY >= 0,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D3D85).withValues(alpha: 0.15),
                    const Color(0xFF0D3D85).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // 2. Forecast Future Projection Line (Dashed Vibrant Orange)
            LineChartBarData(
              spots: forecastSpots,
              isCurved: false,
              dashArray: [6, 4],
              color: const Color(0xFFE8611A),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isLast = index == forecastSpots.length - 1;
                  return FlDotCirclePainter(
                    radius: isLast ? 6 : 4.5,
                    color: const Color(0xFFE8611A),
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.spotIndex;
                  final isForecast = spot.barIndex == 1 && idx > 0;
                  final yearLabel = isForecast
                      ? '${fore[idx - 1].period} (Proyeksi)'
                      : (spot.barIndex == 0 ? '${hist[idx].period}' : '${hist.last.period}');
                  return LineTooltipItem(
                    '$yearLabel\n',
                    GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    children: [
                      TextSpan(
                        text: '${ChartDataParser.formatIndonesianNumber(spot.y)} ${result.unit}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isForecast ? const Color(0xFFFFB74D) : Colors.white,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend(ForecastResult result) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF0D3D85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Data Aktual BPS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Row(
          children: [
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8611A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Garis Proyeksi Tren',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE8611A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParameterControl(ForecastResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF475569)),
                  const SizedBox(width: 6),
                  Text(
                    'Parameter Model (α, β)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Auto Grid-Search',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isAutoOptimized ? AppColors.primaryNavy : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: _isAutoOptimized,
                        activeTrackColor: AppColors.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _isAutoOptimized = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isAutoOptimized
                ? '✨ Parameter α dan β dioptimalkan otomatis oleh engine untuk menghasilkan nilai MAPE terendah (${result.metrics.mape}%).'
                : 'Atur bobot level (α) dan tren (β) secara manual untuk menguji sensitivitas model:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (!_isAutoOptimized) ...[
            const SizedBox(height: 12),
            // Alpha Slider
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    'Alpha (α): ${_manualAlpha.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _manualAlpha,
                    min: 0.05,
                    max: 0.95,
                    divisions: 18,
                    activeColor: AppColors.primaryNavy,
                    onChanged: (val) {
                      setState(() {
                        _manualAlpha = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            // Beta Slider
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    'Beta (β): ${_manualBeta.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _manualBeta,
                    min: 0.05,
                    max: 0.95,
                    divisions: 18,
                    activeColor: const Color(0xFFE8611A),
                    onChanged: (val) {
                      setState(() {
                        _manualBeta = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Optimal Alpha (α): ${result.alpha}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Optimal Beta (β): ${result.beta}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNarrativeCard(ForecastResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text(
                'Insight & Rekomendasi Kebijakan (BPS Demak)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.narrativeInsight,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: const Color(0xFF166534),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableToggle() {
    return InkWell(
      onTap: () {
        setState(() {
          _showDetailsTable = !_showDetailsTable;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    size: 16,
                    color: AppColors.primaryNavy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showDetailsTable
                          ? 'Sembunyikan Tabel Evaluasi Model'
                          : 'Lihat Tabel Evaluasi & Uji Deviasi Model',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _showDetailsTable ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.primaryNavy,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalTable(ForecastResult result) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            horizontalMargin: 12,
            columnSpacing: 18,
            headingTextStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            dataTextStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF334155),
            ),
            columns: const [
              DataColumn(label: Text('Tahun')),
              DataColumn(label: Text('Aktual (Yt)')),
              DataColumn(label: Text('Model (Ft)')),
              DataColumn(label: Text('Error (|e|)')),
              DataColumn(label: Text('Deviasi (%)')),
            ],
            rows: [
              ...result.fitRows.map((row) {
                return DataRow(
                  cells: [
                    DataCell(Text('${row.period}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(ChartDataParser.formatIndonesianNumber(row.actual))),
                    DataCell(Text(ChartDataParser.formatIndonesianNumber(row.fitted))),
                    DataCell(Text(row.absoluteError.toStringAsFixed(2))),
                    DataCell(Text('${row.percentageError.toStringAsFixed(2)}%')),
                  ],
                );
              }),
              // Summary Row
              DataRow(
                color: WidgetStateProperty.all(const Color(0xFFEFF6FF)),
                cells: [
                  const DataCell(Text('Rata-rata', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)))),
                  const DataCell(Text('-')),
                  const DataCell(Text('-')),
                  DataCell(Text('MAD: ${result.metrics.mad}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text('MAPE: ${result.metrics.mape}%', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey.shade400, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
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
}
