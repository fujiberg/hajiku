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

  Map<String, dynamic> toJson() => {
    'meaning': meaning,
    'primary': primary,
    'accepted_answer': acceptedAnswer,
  };
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

  Map<String, dynamic> toJson() => {
    'meaning': meaning,
    'type': type == WaniKaniAuxiliaryMeaningType.whitelist
        ? 'whitelist'
        : 'blacklist',
  };
}

/// The category of a kanji reading. `null` for non-kanji subjects.
enum WaniKaniReadingType { onyomi, kunyomi, nanori }

/// Display label for a [WaniKaniReadingType].
extension WaniKaniReadingTypeLabel on WaniKaniReadingType {
  String get label => switch (this) {
    WaniKaniReadingType.onyomi => "On'yomi",
    WaniKaniReadingType.kunyomi => "Kun'yomi",
    WaniKaniReadingType.nanori => 'Nanori',
  };
}

/// A single reading for a subject, as returned within `readings`.
class WaniKaniReading {
  const WaniKaniReading({
    required this.reading,
    required this.primary,
    required this.acceptedAnswer,
    this.type,
  });

  factory WaniKaniReading.fromJson(Map<String, dynamic> json) {
    return WaniKaniReading(
      reading: json['reading'] as String,
      primary: json['primary'] as bool,
      acceptedAnswer: json['accepted_answer'] as bool,
      type: switch (json['type'] as String?) {
        'onyomi' => WaniKaniReadingType.onyomi,
        'kunyomi' => WaniKaniReadingType.kunyomi,
        'nanori' => WaniKaniReadingType.nanori,
        _ => null,
      },
    );
  }

  final String reading;
  final bool primary;
  final bool acceptedAnswer;

  /// For kanji subjects, whether this is an on'yomi, kun'yomi, or nanori
  /// reading. `null` for radicals and vocabulary.
  final WaniKaniReadingType? type;

  Map<String, dynamic> toJson() => {
    'reading': reading,
    'primary': primary,
    'accepted_answer': acceptedAnswer,
    'type': switch (type) {
      WaniKaniReadingType.onyomi => 'onyomi',
      WaniKaniReadingType.kunyomi => 'kunyomi',
      WaniKaniReadingType.nanori => 'nanori',
      null => null,
    },
  };
}

/// An example sentence for a vocabulary subject, as returned within
/// `context_sentences`.
class WaniKaniContextSentence {
  const WaniKaniContextSentence({
    required this.english,
    required this.japanese,
  });

  factory WaniKaniContextSentence.fromJson(Map<String, dynamic> json) {
    return WaniKaniContextSentence(
      english: json['en'] as String,
      japanese: json['ja'] as String,
    );
  }

  final String english;
  final String japanese;

  Map<String, dynamic> toJson() => {'en': english, 'ja': japanese};
}

/// A voice actor's recording of a subject's reading, as returned within
/// `pronunciation_audios`.
class WaniKaniPronunciationAudio {
  const WaniKaniPronunciationAudio({
    required this.url,
    required this.contentType,
    this.pronunciation,
    this.voiceActorName,
  });

  factory WaniKaniPronunciationAudio.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>?;
    return WaniKaniPronunciationAudio(
      url: json['url'] as String,
      contentType: json['content_type'] as String,
      pronunciation: metadata?['pronunciation'] as String?,
      voiceActorName: metadata?['voice_actor_name'] as String?,
    );
  }

  /// Location of the audio file.
  final String url;

  /// The audio format, e.g. `audio/mpeg` or `audio/ogg`.
  final String contentType;

  /// The reading this recording pronounces.
  final String? pronunciation;

  /// The name of the voice actor who recorded this clip.
  final String? voiceActorName;

  Map<String, dynamic> toJson() => {
    'url': url,
    'content_type': contentType,
    'metadata': {
      'pronunciation': pronunciation,
      'voice_actor_name': voiceActorName,
    },
  };
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
    this.meaningMnemonic,
    this.readingMnemonic,
    this.contextSentences = const [],
    this.pronunciationAudios = const [],
  });

  factory WaniKaniSubject.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final readings = data['readings'] as List<dynamic>?;
    final auxiliaryMeanings = data['auxiliary_meanings'] as List<dynamic>?;
    final contextSentences = data['context_sentences'] as List<dynamic>?;
    final pronunciationAudios = data['pronunciation_audios'] as List<dynamic>?;

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
      meaningMnemonic: data['meaning_mnemonic'] as String?,
      readingMnemonic: data['reading_mnemonic'] as String?,
      contextSentences: (contextSentences ?? const [])
          .map(
            (e) => WaniKaniContextSentence.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      pronunciationAudios: (pronunciationAudios ?? const [])
          .map(
            (e) =>
                WaniKaniPronunciationAudio.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Serializes back into the same shape WaniKani's `GET /subjects` returns,
  /// so a round-trip through [fromJson] reproduces this subject. Used to
  /// persist subjects in the on-device cache.
  Map<String, dynamic> toJson() => {
    'id': id,
    'object': type.apiValue,
    'data': {
      'characters': characters,
      'slug': slug,
      'meanings': [for (final m in meanings) m.toJson()],
      'auxiliary_meanings': [for (final m in auxiliaryMeanings) m.toJson()],
      'readings': [for (final r in readings) r.toJson()],
      'meaning_mnemonic': meaningMnemonic,
      'reading_mnemonic': readingMnemonic,
      'context_sentences': [for (final s in contextSentences) s.toJson()],
      'pronunciation_audios': [for (final a in pronunciationAudios) a.toJson()],
    },
  };

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

  /// Mnemonic explaining how to remember the meaning, with WaniKani's markup
  /// tags (e.g. `<radical>`, `<meaning>`) marking emphasized terms.
  final String? meaningMnemonic;

  /// Mnemonic explaining how to remember the reading. `null` for radicals
  /// and subjects without a reading.
  final String? readingMnemonic;

  /// Example sentences using this subject. Empty for radicals and kanji.
  final List<WaniKaniContextSentence> contextSentences;

  /// Voice actor recordings of this subject's reading. Empty for radicals
  /// and kanji.
  final List<WaniKaniPronunciationAudio> pronunciationAudios;

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
