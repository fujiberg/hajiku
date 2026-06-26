/// User-created study material for a subject, as returned by
/// `GET /study_materials`. Only the meaning synonyms are stored — notes and
/// other fields aren't used for answer validation.
class WaniKaniStudyMaterial {
  const WaniKaniStudyMaterial({
    required this.id,
    required this.subjectId,
    required this.meaningSynonyms,
  });

  factory WaniKaniStudyMaterial.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return WaniKaniStudyMaterial(
      id: json['id'] as int,
      subjectId: data['subject_id'] as int,
      meaningSynonyms: (data['meaning_synonyms'] as List<dynamic>).cast<String>(),
    );
  }

  factory WaniKaniStudyMaterial.fromCacheJson(Map<String, dynamic> json) {
    return WaniKaniStudyMaterial(
      id: json['id'] as int,
      subjectId: json['subject_id'] as int,
      meaningSynonyms: (json['meaning_synonyms'] as List<dynamic>).cast<String>(),
    );
  }

  final int id;
  final int subjectId;
  final List<String> meaningSynonyms;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject_id': subjectId,
    'meaning_synonyms': meaningSynonyms,
  };
}
