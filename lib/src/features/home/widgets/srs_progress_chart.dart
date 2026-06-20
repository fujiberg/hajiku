import 'package:flutter/material.dart';

import '../../../core/theme/srs_stage_style.dart';

/// A stacked bar showing how the user's items are distributed across SRS
/// stages, from "Apprentice" (just learned) to "Burned" (fully learned).
class SrsProgressChart extends StatelessWidget {
  const SrsProgressChart({required this.distribution, super.key});

  final Map<SrsStageBucket, int> distribution;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = distribution.values.fold<int>(0, (sum, count) => sum + count);
    final burned = distribution[SrsStageBucket.burned] ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SRS progress', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'No items in progress yet.'
                  : '$burned of $total items burned',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      for (final bucket in SrsStageBucket.values)
                        if ((distribution[bucket] ?? 0) > 0)
                          Expanded(
                            flex: distribution[bucket]!,
                            child: Container(color: bucket.color),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final bucket in SrsStageBucket.values)
                    _LegendEntry(
                      bucket: bucket,
                      count: distribution[bucket] ?? 0,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single "● Apprentice: 12" legend entry.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.bucket, required this.count});

  final SrsStageBucket bucket;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: bucket.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${bucket.label}: $count',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
