import 'wanikani_assignment.dart';

/// A single meaning for a subject, as returned within `meanings`.
class WaniKaniMeaning {
  const WaniKaniMeaning({
    required this.meaning,
    required this.primary,
    required this.acceptedAnswer,
  });

  factory WaniKaniMeaning.fromJson(Map<String, dynamic> json) {
    return WaniKaniMeaning(
      meaning: json['meaning'] as String,
      primary: json['primary'] as bool,
      acceptedAnswer: json['accepted_answer'] as bool,
    );
  }

  final String meaning;
  final bool primary;
  final bool acceptedAnswer;
}

/// Whether an auxiliary meaning is an additionally accepted answer
/// (`whitelist`) or an explicitly rejected one (`blacklist`).
enum WaniKaniAuxiliaryMeaningType { whitelist, blacklist }

/// An additional meaning, as returned within `auxiliary_meanings`.
class WaniKaniAuxiliaryMeaning {
  const WaniKaniAuxiliaryMeaning({required this.meaning, required this.type});

  factory WaniKaniAuxiliaryMeaning.fromJson(Map<String, dynamic> json) {
    return WaniKaniAuxiliaryMeaning(
      meaning: json['meaning'] as String,
      type: json['type'] == 'whitelist'
          ? WaniKaniAuxiliaryMeaningType.whitelist
          : WaniKaniAuxiliaryMeaningType.blacklist,
    );
  }

  final String meaning;
  final WaniKaniAuxiliaryMeaningType type;
}

/// A single reading for a subject, as returned within `readings`.
class WaniKaniReading {
  const WaniKaniReading({
    required this.reading,
    required this.primary,
    required this.acceptedAnswer,
  });

  factory WaniKaniReading.fromJson(Map<String, dynamic> json) {
    return WaniKaniReading(
      reading: json['reading'] as String,
      primary: json['primary'] as bool,
      acceptedAnswer: json['accepted_answer'] as bool,
    );
  }

  final String reading;
  final bool primary;
  final bool acceptedAnswer;
}

/// A radical, kanji, or vocabulary subject, as returned by `GET /subjects`.
class WaniKaniSubject {
  const WaniKaniSubject({
    required this.id,
    required this.type,
    required this.characters,
    required this.slug,
    required this.meanings,
    required this.auxiliaryMeanings,
    required this.readings,
  });

  factory WaniKaniSubject.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final readings = data['readings'] as List<dynamic>?;
    final auxiliaryMeanings = data['auxiliary_meanings'] as List<dynamic>?;

    return WaniKaniSubject(
      id: json['id'] as int,
      type: WaniKaniSubjectType.fromApiValue(json['object'] as String),
      characters: data['characters'] as String?,
      slug: data['slug'] as String,
      meanings: (data['meanings'] as List<dynamic>)
          .map((e) => WaniKaniMeaning.fromJson(e as Map<String, dynamic>))
          .toList(),
      auxiliaryMeanings: (auxiliaryMeanings ?? const [])
          .map(
            (e) => WaniKaniAuxiliaryMeaning.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      readings: (readings ?? const [])
          .map((e) => WaniKaniReading.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final WaniKaniSubjectType type;

  /// The subject's characters, or `null` for radicals with no unicode
  /// representation (use [slug] as a fallback for those).
  final String? characters;

  /// A short text identifier, used as a display fallback when [characters]
  /// is `null`.
  final String slug;

  final List<WaniKaniMeaning> meanings;
  final List<WaniKaniAuxiliaryMeaning> auxiliaryMeanings;

  /// Accepted readings, in kana. Empty for radicals.
  final List<WaniKaniReading> readings;

  /// The text to display for this subject.
  String get displayText => characters ?? slug;

  /// Meanings and whitelisted auxiliary meanings accepted as correct
  /// answers to a "meaning" quiz.
  List<String> get acceptedMeanings => [
    for (final meaning in meanings)
      if (meaning.acceptedAnswer) meaning.meaning,
    for (final meaning in auxiliaryMeanings)
      if (meaning.type == WaniKaniAuxiliaryMeaningType.whitelist)
        meaning.meaning,
  ];

  /// Readings accepted as correct answers to a "reading" quiz.
  List<String> get acceptedReadings => [
    for (final reading in readings)
      if (reading.acceptedAnswer) reading.reading,
  ];

  /// The primary meaning, shown as "the" correct answer in feedback.
  String get primaryMeaning => meanings
      .firstWhere((m) => m.primary, orElse: () => meanings.first)
      .meaning;

  /// The primary reading, shown as "the" correct answer in feedback.
  /// Only valid when [readings] is non-empty.
  String get primaryReading => readings
      .firstWhere((r) => r.primary, orElse: () => readings.first)
      .reading;
}
