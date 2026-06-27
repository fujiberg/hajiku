import 'dart:convert';
import 'dart:io';

import '../wanikani/models/wanikani_subject.dart';

/// On-device store for WaniKani subjects (the learning information: meanings,
/// readings, mnemonics, audio metadata). Subjects change very rarely, so once
/// cached they're served locally; the resource layer only refetches missing
/// ones and revalidates the rest via `updated_after`.
///
/// Each subject is stored as a `<id>.json` file under a `subjects/`
/// subdirectory of [directory]; a sibling metadata file records when the
/// cache was last revalidated against the API.
class SubjectCache {
  SubjectCache({required this._directory});

  final Directory _directory;

  Directory get _subjectsDir =>
      Directory('${_directory.path}${Platform.pathSeparator}subjects');

  File _fileFor(int id) =>
      File('${_subjectsDir.path}${Platform.pathSeparator}$id.json');

  File get _metaFile =>
      File('${_directory.path}${Platform.pathSeparator}subjects_meta.json');

  /// Returns the cached subjects among [ids], keyed by id. Ids with no cached
  /// entry are simply absent from the result.
  Future<Map<int, WaniKaniSubject>> getMany(Iterable<int> ids) async {
    final result = <int, WaniKaniSubject>{};
    for (final id in ids) {
      final file = _fileFor(id);
      if (!file.existsSync()) continue;
      try {
        final json = jsonDecode(await file.readAsString());
        result[id] = WaniKaniSubject.fromJson(json as Map<String, dynamic>);
      } on FormatException {
        // Corrupt entry — drop it so it's refetched.
        await file.delete();
      }
    }
    return result;
  }

  /// Writes [subjects] to the cache, overwriting any existing entries.
  Future<void> putAll(Iterable<WaniKaniSubject> subjects) async {
    if (subjects.isEmpty) return;
    await _subjectsDir.create(recursive: true);
    for (final subject in subjects) {
      await _fileFor(subject.id).writeAsString(jsonEncode(subject.toJson()));
    }
  }

  /// When the cache was last revalidated against the API, or `null` if it
  /// never has been. Passed as `updated_after` to fetch only changed subjects.
  Future<DateTime?> syncedAt() async {
    if (!_metaFile.existsSync()) return null;
    try {
      final json = jsonDecode(await _metaFile.readAsString());
      final value = (json as Map<String, dynamic>)['synced_at'] as String?;
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

  /// Returns every subject currently in the cache.
  Future<List<WaniKaniSubject>> getAll() async {
    if (!_subjectsDir.existsSync()) return const [];
    final subjects = <WaniKaniSubject>[];
    for (final entity in _subjectsDir.listSync()) {
      if (entity is! File) continue;
      try {
        final json = jsonDecode(await entity.readAsString());
        subjects.add(WaniKaniSubject.fromJson(json as Map<String, dynamic>));
      } on FormatException {
        await entity.delete();
      }
    }
    return subjects;
  }

  /// The number of subjects currently cached.
  Future<int> count() async {
    if (!_subjectsDir.existsSync()) return 0;
    return _subjectsDir.listSync().whereType<File>().length;
  }

  /// Removes every cached subject and the revalidation metadata.
  Future<void> clear() async {
    if (_subjectsDir.existsSync()) {
      await _subjectsDir.delete(recursive: true);
    }
    if (_metaFile.existsSync()) {
      await _metaFile.delete();
    }
  }
}
