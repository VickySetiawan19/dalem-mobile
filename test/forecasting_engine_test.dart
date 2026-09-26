import 'package:flutter_test/flutter_test.dart';
import 'package:Dalem/engine/forecasting_models.dart';
import 'package:Dalem/engine/forecasting_engine.dart';

void main() {
  group('ForecastingEngine - Double Exponential Smoothing (Holt\'s Method)', () {
    // Real BPS Demak Kemiskinan time series data (2019 - 2024)
    final povertyData = [
      const TimeSeriesPoint(period: 2019, value: 12.45),
      const TimeSeriesPoint(period: 2020, value: 12.30),
      const TimeSeriesPoint(period: 2021, value: 12.18),
      const TimeSeriesPoint(period: 2022, value: 12.09),
      const TimeSeriesPoint(period: 2023, value: 11.95),
      const TimeSeriesPoint(period: 2024, value: 11.92),
    ];

    test('Computes DES and produces valid forecast points for next 2 years', () {
      final result = ForecastingEngine.runDoubleExponentialSmoothing(
        povertyData,
        alpha: 0.3,
        beta: 0.1,
        horizon: 2,
        indicatorTitle: 'Persentase Kemiskinan',
        unit: '%',
      );

      expect(result.historicalData.length, equals(6));
      expect(result.forecasts.length, equals(2));
      expect(result.forecasts[0].period, equals(2025));
      expect(result.forecasts[1].period, equals(2026));

      // Poverty has downward trend, so forecasted value should be lower than initial
      expect(result.forecasts[0].value, lessThan(12.45));
      expect(result.forecasts[0].lowerBound, lessThan(result.forecasts[0].value));
      expect(result.forecasts[0].upperBound, greaterThan(result.forecasts[0].value));

      // Accuracy metrics must be valid numbers
      expect(result.metrics.mape, greaterThan(0.0));
      expect(result.metrics.mape, lessThan(10.0)); // Should be highly accurate (<10%)
      expect(result.metrics.isHighlyAccurate, isTrue);
      expect(result.metrics.category, contains('Sangat Baik'));
    });

    test('Grid Search Optimizer finds optimal alpha and beta that minimizes MAPE', () {
      final optimal = ForecastingEngine.findOptimalParameters(povertyData);
      expect(optimal.containsKey('alpha'), isTrue);
      expect(optimal.containsKey('beta'), isTrue);
      expect(optimal['alpha']!, inInclusiveRange(0.05, 0.95));
      expect(optimal['beta']!, inInclusiveRange(0.05, 0.95));

      final autoResult = ForecastingEngine.runDoubleExponentialSmoothing(
        povertyData,
        indicatorTitle: 'Persentase Kemiskinan Demak',
        unit: '%',
      );

      expect(autoResult.metrics.mape, isNotNull);
      expect(autoResult.narrativeInsight, isNotEmpty);
      expect(autoResult.fitRows.length, equals(6));
    });
  });
}
