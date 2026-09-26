import 'package:flutter_test/flutter_test.dart';
import 'package:Dalem/services/offline_seed_data.dart';
import 'package:Dalem/services/bps_api_service.dart';
import 'package:Dalem/charts/chart_data_parser.dart';
import 'package:Dalem/engine/forecasting_engine.dart';
import 'package:Dalem/engine/forecasting_models.dart';

void main() {
  group('Offline Resilience & Seed Fallback Tests', () {
    test('OfflineSeedData returns valid strategic tables list format', () {
      final seedList = OfflineSeedData.getStrategicTablesList();
      expect(seedList['status'], equals('OK'));
      expect(seedList['data'], isA<List>());
      final items = seedList['data'][1] as List;
      expect(items.length, greaterThanOrEqualTo(5));
      expect(items[0]['title'], contains('Miskin'));
    });

    test('OfflineSeedData dynamic data parses correctly into ChartSeries and runs Forecasting', () {
      final dynamicData = OfflineSeedData.getDynamicTableData('kemiskinan_demak');
      expect(dynamicData['status'], equals('OK'));
      expect(dynamicData['is_seed_offline'], isTrue);

      final rawTahun = (dynamicData['tahun'] as List).cast<Map<String, dynamic>>();
      final seriesList = ChartDataParser.parseDynamic(dynamicData, filteredTahun: rawTahun);
      expect(seriesList.isNotEmpty, isTrue);

      final firstSeries = seriesList.first;
      expect(firstSeries.points.length, greaterThanOrEqualTo(2));

      // Extract time-series points
      final timePoints = <TimeSeriesPoint>[];
      for (var p in firstSeries.points) {
        final year = int.tryParse(p.label.trim());
        if (year != null) {
          timePoints.add(TimeSeriesPoint(period: year, value: p.value));
        }
      }

      expect(timePoints.length, greaterThanOrEqualTo(2));

      // Verify Forecasting Engine can run on offline seed data without network
      final forecast = ForecastingEngine.runDoubleExponentialSmoothing(
        timePoints,
        horizon: 2,
        indicatorTitle: 'Kemiskinan Demak (Offline Seed)',
      );

      expect(forecast.forecasts.length, equals(2));
      expect(forecast.metrics.mape, isNotNull);
      expect(forecast.metrics.mape, lessThan(10.0)); // Highly accurate
    });

    test('BpsApiService falls back to seed data when network fails', () async {
      // Mock unreachable fake URL
      const fakeUrl = 'https://fake-unreachable-bps-server.invalid/api/list/model/tablestatistic/keyword/strategis';
      final result = await BpsApiService.fetchJson(fakeUrl);

      expect(result['_is_offline'], isTrue);
      expect(result['_offline_source'], equals('seed'));
      expect(result['data'], isNotNull);
    });
  });
}
