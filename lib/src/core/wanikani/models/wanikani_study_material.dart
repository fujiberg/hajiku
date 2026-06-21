/// User-created study material for a subject, as returned by
/// `GET /study_materials`. Only the meaning synonyms are stored — notes and
/// other fields aren't used for answer validation.
class WaniKaniStudyMaterial {
  const WaniKaniStudyMaterial({
    required this.subjectId,
    required this.meaningSynonyms,
  });

  factory WaniKaniStudyMaterial.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return WaniKaniStudyMaterial(
      subjectId: data['subject_id'] as int,
      meaningSynonyms: (data['meaning_synonyms'] as List<dynamic>).cast<String>(),
    );
  }

  final int subjectId;
  final List<String> meaningSynonyms;
}
