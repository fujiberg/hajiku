/// The subject types returned by the WaniKani API.
enum WaniKaniSubjectType {
  radical,
  kanji,
  vocabulary,
  kanaVocabulary;

  /// Parses the `subject_type` value as returned by the WaniKani API.
  static WaniKaniSubjectType fromApiValue(String value) {
    switch (value) {
      case 'radical':
        return WaniKaniSubjectType.radical;
      case 'kanji':
        return WaniKaniSubjectType.kanji;
      case 'vocabulary':
        return WaniKaniSubjectType.vocabulary;
      case 'kana_vocabulary':
        return WaniKaniSubjectType.kanaVocabulary;
      default:
        throw ArgumentError('Unknown WaniKani subject type: $value');
    }
  }

  /// The `object`/`subject_type` value as used by the WaniKani API.
  String get apiValue => switch (this) {
    WaniKaniSubjectType.radical => 'radical',
    WaniKaniSubjectType.kanji => 'kanji',
    WaniKaniSubjectType.vocabulary => 'vocabulary',
    WaniKaniSubjectType.kanaVocabulary => 'kana_vocabulary',
  };
}

/// A user's progress on a single subject, as returned by `GET /assignments`.
class WaniKaniAssignment {
  factory WaniKaniAssignment.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final availableAt = data['available_at'] as String?;
    return WaniKaniAssignment(
      id: json['id'] as int,
      subjectId: data['subject_id'] as int,
      subjectType: WaniKaniSubjectType.fromApiValue(
        data['subject_type'] as String,
      ),
      srsStage: data['srs_stage'] as int,
      availableAt: availableAt == null ? null : DateTime.parse(availableAt),
    );
  }

  const WaniKaniAssignment({
    required this.id,
    required this.subjectId,
    required this.subjectType,
    required this.srsStage,
    this.availableAt,
  });

  /// The assignment's own ID, used when submitting review results.
  final int id;

  /// The ID of the subject (radical/kanji/vocabulary) being reviewed.
  final int subjectId;

  final WaniKaniSubjectType subjectType;
  final int srsStage;

  /// When this assignment's next review becomes available, or `null` if it
  /// has no upcoming review (not yet started, or burned).
  final DateTime? availableAt;
}
