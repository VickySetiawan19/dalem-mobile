/// Model and data structures for the Statistical Forecasting Engine
/// Designed for BPS Kabupaten Demak Time-Series Indicators (Tugas Akhir RPL).
library;

enum ForecastMethod {
  doubleExponentialSmoothing, // Holt's Linear Trend (Primary)
  singleExponentialSmoothing, // SES Baseline
  linearRegression, // Linear Trend Projection
}

/// A single observation in the time-series.
class TimeSeriesPoint {
  final int period; // e.g. 2020, 2021, 2022
  final double value; // e.g. 12.09
  final String label;

  const TimeSeriesPoint({
    required this.period,
    required this.value,
    String? label,
  }) : label = label ?? '$period';

  @override
  String toString() => '$label: $value';
}

/// A forecasted future point.
class ForecastPoint {
  final int period;
  final double value;
  final double lowerBound; // 95% Confidence Interval lower bound
  final double upperBound; // 95% Confidence Interval upper bound
  final String label;

  const ForecastPoint({
    required this.period,
    required this.value,
    required this.lowerBound,
    required this.upperBound,
    String? label,
  }) : label = label ?? '$period';
}

/// Evaluation metrics for model validation (Standard criteria for thesis / TA).
class AccuracyMetrics {
  /// Mean Absolute Percentage Error (%)
  final double mape;

  /// Mean Absolute Deviation
  final double mad;

  /// Mean Squared Error
  final double mse;

  /// Root Mean Squared Error
  final double rmse;

  /// Qualitative category based on Lewis (1982) criteria.
  final String category;

  const AccuracyMetrics({
    required this.mape,
    required this.mad,
    required this.mse,
    required this.rmse,
    required this.category,
  });

  /// True if MAPE < 10% (Sangat Baik / Highly Accurate)
  bool get isHighlyAccurate => mape < 10.0;

  /// Accuracy percentage (100 - MAPE) clamped to 0-100%
  double get accuracyScore => (100.0 - mape).clamp(0.0, 100.0);
}

/// Detailed historical row comparison (Aktual vs Fitted vs Error)
class HistoricalFitRow {
  final int period;
  final double actual;
  final double fitted;
  final double absoluteError;
  final double percentageError;

  const HistoricalFitRow({
    required this.period,
    required this.actual,
    required this.fitted,
    required this.absoluteError,
    required this.percentageError,
  });
}

/// Complete output from the forecasting engine.
class ForecastResult {
  final String indicatorTitle;
  final String unit;
  final ForecastMethod method;
  final List<TimeSeriesPoint> historicalData;
  final List<ForecastPoint> forecasts;
  final List<HistoricalFitRow> fitRows;
  final AccuracyMetrics metrics;
  final double alpha; // Smoothing factor for level
  final double beta; // Smoothing factor for trend
  final double averageGrowthRate; // Rata-rata laju pertumbuhan tahunan
  final String trendDirection; // 'Naik', 'Turun', 'Stabil'
  final String narrativeInsight; // Kesimpulan deskriptif otomatis

  const ForecastResult({
    required this.indicatorTitle,
    required this.unit,
    required this.method,
    required this.historicalData,
    required this.forecasts,
    required this.fitRows,
    required this.metrics,
    required this.alpha,
    required this.beta,
    required this.averageGrowthRate,
    required this.trendDirection,
    required this.narrativeInsight,
  });
}
