import 'package:flutter/material.dart';

import '../wanikani/models/wanikani_assignment.dart';

/// Visual styling for each WaniKani subject type, following WaniKani's own
/// color and iconography conventions.
extension SubjectTypeStyle on WaniKaniSubjectType {
  /// The brand color associated with this subject type.
  Color get color => switch (this) {
    WaniKaniSubjectType.radical => const Color(0xFF00AAFF),
    WaniKaniSubjectType.kanji => const Color(0xFFFF00AA),
    WaniKaniSubjectType.vocabulary => const Color(0xFFAA00FF),
    WaniKaniSubjectType.kanaVocabulary => const Color(0xFF00AA82),
  };

  /// A single kanji character representing this subject type.
  String get glyph => switch (this) {
    WaniKaniSubjectType.radical => '幺',
    WaniKaniSubjectType.kanji => '字',
    WaniKaniSubjectType.vocabulary => '語',
    WaniKaniSubjectType.kanaVocabulary => '仮',
  };

  /// A human-readable label for this subject type.
  String get label => switch (this) {
    WaniKaniSubjectType.radical => 'Radicals',
    WaniKaniSubjectType.kanji => 'Kanji',
    WaniKaniSubjectType.vocabulary => 'Vocabulary',
    WaniKaniSubjectType.kanaVocabulary => 'Kana vocab',
  };
}
