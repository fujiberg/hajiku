import 'package:flutter/material.dart';

/// The stages of WaniKani's SRS, grouped the way WaniKani's own dashboard
/// groups them (each "Apprentice"/"Guru" group spans multiple numeric
/// `srs_stage` values).
enum SrsStageBucket {
  apprentice,
  guru,
  master,
  enlightened,
  burned;

  /// The raw `srs_stage` values (as returned by the WaniKani API) that fall
  /// into this bucket.
  List<int> get stages => switch (this) {
    SrsStageBucket.apprentice => const [1, 2, 3, 4],
    SrsStageBucket.guru => const [5, 6],
    SrsStageBucket.master => const [7],
    SrsStageBucket.enlightened => const [8],
    SrsStageBucket.burned => const [9],
  };

  /// The bucket containing the given raw `srs_stage` value, or `null` for
  /// stage 0 (lesson not yet done, no SRS progress).
  static SrsStageBucket? forSrsStage(int srsStage) {
    for (final bucket in values) {
      if (bucket.stages.contains(srsStage)) return bucket;
    }
    return null;
  }
}

/// Visual styling for each [SrsStageBucket], following WaniKani's own SRS
/// stage colors.
extension SrsStageStyle on SrsStageBucket {
  /// The brand color associated with this SRS stage.
  Color get color => switch (this) {
    SrsStageBucket.apprentice => const Color(0xFFDD0093),
    SrsStageBucket.guru => const Color(0xFF882D9E),
    SrsStageBucket.master => const Color(0xFF294DDB),
    SrsStageBucket.enlightened => const Color(0xFF0093DD),
    SrsStageBucket.burned => const Color(0xFF434343),
  };

  /// A human-readable label for this SRS stage.
  String get label => switch (this) {
    SrsStageBucket.apprentice => 'Apprentice',
    SrsStageBucket.guru => 'Guru',
    SrsStageBucket.master => 'Master',
    SrsStageBucket.enlightened => 'Enlightened',
    SrsStageBucket.burned => 'Burned',
  };
}
