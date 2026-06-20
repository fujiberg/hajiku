import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/srs_stage_style.dart';
import '../../../core/wanikani/models/wanikani_assignment.dart';

/// A stacked area chart showing how the review queue grows over the next 24
/// hours, layered by the SRS stage of the items becoming due.
class ReviewForecastChart extends StatelessWidget {
  const ReviewForecastChart({required this.assignments, super.key});

  final List<WaniKaniAssignment> assignments;

  static const _hoursShown = 24;

  /// Stacking order from bottom to top.
  static const _bands = [
    SrsStageBucket.apprentice,
    SrsStageBucket.guru,
    SrsStageBucket.master,
    SrsStageBucket.enlightened,
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);

    // perHour[bucket][hour] = reviews from that bucket becoming due in that
    // hour (hour 0 also absorbs anything already overdue).
    final perHour = {
      for (final bucket in _bands) bucket: List<int>.filled(_hoursShown, 0),
    };

    for (final assignment in assignments) {
      final availableAt = assignment.availableAt;
      if (availableAt == null) continue;

      final bucket = SrsStageBucket.forSrsStage(assignment.srsStage);
      if (bucket == null || !_bands.contains(bucket)) continue;

      final hoursFromNow = availableAt.difference(currentHour).inHours;
      final hour = hoursFromNow.clamp(0, _hoursShown - 1);
      perHour[bucket]![hour] = perHour[bucket]![hour] + 1;
    }

    // stack[i][hour] = cumulative total of bands 0..i, due by the end of
    // that hour. Drawn back-to-front (last band first) so each narrower
    // band's fill paints over the wider one beneath it.
    final stack = List.generate(
      _bands.length,
      (_) => List<int>.filled(_hoursShown, 0),
    );
    for (var hour = 0; hour < _hoursShown; hour++) {
      var running = 0;
      for (var i = 0; i < _bands.length; i++) {
        running += perHour[_bands[i]]![hour];
        stack[i][hour] = running;
      }
      if (hour > 0) {
        for (var i = 0; i < _bands.length; i++) {
          stack[i][hour] += stack[i][hour - 1];
        }
      }
    }

    final total = stack.last.last;
    final maxY = stack.last.reduce((a, b) => a > b ? a : b);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming reviews', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'Nothing due in the next 24 hours.'
                  : '$total review${total == 1 ? '' : 's'} over the next 24 hours',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (maxY > 0)
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (_hoursShown - 1).toDouble(),
                    minY: 0,
                    maxY: maxY * 1.1,
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: false,
                      verticalInterval: 3,
                      getDrawingVerticalLine: (value) => FlLine(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) => Text(
                            value.round().toString(),
                            style: textTheme.labelSmall,
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 3,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final hour = value.round();
                            // fl_chart also labels the right edge (hour 23)
                            // to avoid a gap; skip it since it doesn't line
                            // up with the 3-hour grid.
                            if (hour % 3 != 0) return const SizedBox.shrink();

                            final label = hour == 0 ? 'Now' : '+${hour}h';
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(label, style: textTheme.labelSmall),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      // Drawn from the topmost band down, so each
                      // subsequent (narrower) area paints over the rest.
                      for (var i = _bands.length - 1; i >= 0; i--)
                        LineChartBarData(
                          spots: [
                            for (var hour = 0; hour < _hoursShown; hour++)
                              FlSpot(
                                hour.toDouble(),
                                stack[i][hour].toDouble(),
                              ),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.15,
                          color: _bands[i].color,
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _bands[i].color.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
