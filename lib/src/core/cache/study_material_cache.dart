import 'dart:convert';
import 'dart:io';

import '../wanikani/models/wanikani_study_material.dart';

/// On-device store for WaniKani study materials (user-created meaning synonyms).
/// Mirrors the [SubjectCache] pattern: one `<subjectId>.json` file per material
/// under a `study_materials/` subdirectory, with a sibling metadata file
/// tracking when the cache was last revalidated so incremental `updated_after`
/// fetches can be used on subsequent loads.
class StudyMaterialCache {
  StudyMaterialCache({required this._directory});

  final Directory _directory;

  Directory get _materialsDir =>
      Directory('${_directory.path}${Platform.pathSeparator}study_materials');

  File _fileFor(int subjectId) =>
      File('${_materialsDir.path}${Platform.pathSeparator}$subjectId.json');

  File get _metaFile => File(
    '${_directory.path}${Platform.pathSeparator}study_materials_meta.json',
  );

  /// Returns all cached study materials, keyed by subject id.
  Future<Map<int, WaniKaniStudyMaterial>> getAll() async {
    if (!_materialsDir.existsSync()) return {};
    final result = <int, WaniKaniStudyMaterial>{};
    for (final entity in _materialsDir.listSync()) {
      if (entity is! File) continue;
      try {
        final json = jsonDecode(await entity.readAsString());
        final material = WaniKaniStudyMaterial.fromCacheJson(
          json as Map<String, dynamic>,
        );
        result[material.subjectId] = material;
      } on FormatException {
        await entity.delete();
      }
    }
    return result;
  }

  /// Writes [materials] to the cache, overwriting any existing entries for
  /// the same subject ids.
  Future<void> putAll(Iterable<WaniKaniStudyMaterial> materials) async {
    if (materials.isEmpty) return;
    await _materialsDir.create(recursive: true);
    for (final material in materials) {
      await _fileFor(material.subjectId).writeAsString(
        jsonEncode(material.toJson()),
      );
    }
  }

  /// Writes a single [material] to the cache.
  Future<void> put(WaniKaniStudyMaterial material) => putAll([material]);

  /// When the cache was last revalidated against the API, or `null` if it
  /// never has been. Passed as `updated_after` to fetch only changed materials.
  Future<DateTime?> syncedAt() async {
    if (!_metaFile.existsSync()) return null;
    try {
      final json = jsonDecode(await _metaFile.readAsString());
      final value =
          (json as Map<String, dynamic>)['synced_at'] as String?;
      return value == null ? null : DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> setSyncedAt(DateTime value) async {
    await _directory.create(recursive: true);
    await _metaFile.writeAsString(
      jsonEncode({'synced_at': value.toUtc().toIso8601String()}),
    );
  }

  /// Removes all cached materials and the revalidation metadata.
  Future<void> clear() async {
    if (_materialsDir.existsSync()) {
      await _materialsDir.delete(recursive: true);
    }
    if (_metaFile.existsSync()) {
      await _metaFile.delete();
    }
  }
}
