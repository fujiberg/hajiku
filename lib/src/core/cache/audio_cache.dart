import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// On-device store for pronunciation audio clips. Each clip is saved as a file
/// named after a hash of its source URL, so the same clip is only ever
/// downloaded once. Files live under an `audio/` subdirectory of [directory].
class AudioCache {
  AudioCache({required this._directory, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Directory _directory;
  final http.Client _httpClient;

  Directory get _audioDir =>
      Directory('${_directory.path}${Platform.pathSeparator}audio');

  File _fileFor(String url) {
    final hash = sha1.convert(url.codeUnits).toString();
    final ext = _extensionFor(url);
    return File('${_audioDir.path}${Platform.pathSeparator}$hash$ext');
  }

  /// Derives a file extension from the URL's path, defaulting to `.mp3`.
  String _extensionFor(String url) {
    final path = Uri.parse(url).path;
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot < path.lastIndexOf('/')) return '.mp3';
    return path.substring(dot);
  }

  /// The local file for [url] if it's already cached, otherwise `null`.
  File? cached(String url) {
    final file = _fileFor(url);
    return file.existsSync() ? file : null;
  }

  /// Returns the cached file for [url], downloading and storing it first if
  /// necessary. Returns `null` if the download fails.
  Future<File?> getOrDownload(String url) async {
    final existing = cached(url);
    if (existing != null) return existing;
    return download(url);
  }

  /// Downloads [url] into the cache, overwriting any existing file, and
  /// returns it. Returns `null` if the request fails.
  Future<File?> download(String url) async {
    final http.Response response;
    try {
      response = await _httpClient.get(Uri.parse(url));
    } on http.ClientException {
      return null;
    } on SocketException {
      return null;
    }
    if (response.statusCode != 200) return null;

    await _audioDir.create(recursive: true);
    final file = _fileFor(url);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// The number of cached clips and their total size in bytes.
  Future<({int count, int bytes})> usage() async {
    if (!_audioDir.existsSync()) return (count: 0, bytes: 0);
    var count = 0;
    var bytes = 0;
    for (final entity in _audioDir.listSync()) {
      if (entity is File) {
        count++;
        bytes += entity.lengthSync();
      }
    }
    return (count: count, bytes: bytes);
  }

  /// Removes every cached audio file.
  Future<void> clear() async {
    if (_audioDir.existsSync()) {
      await _audioDir.delete(recursive: true);
    }
  }
}
