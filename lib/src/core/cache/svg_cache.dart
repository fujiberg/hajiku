import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// On-device store for radical SVG images. Each file is saved under a hash of
/// its source URL. Files live under an `svg/` subdirectory of [directory].
class SvgCache {
  SvgCache({required this._directory, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Directory _directory;
  final http.Client _httpClient;

  Directory get _svgDir =>
      Directory('${_directory.path}${Platform.pathSeparator}svg');

  File _fileFor(String url) {
    final hash = sha1.convert(url.codeUnits).toString();
    return File('${_svgDir.path}${Platform.pathSeparator}$hash.svg');
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
    return _download(url);
  }

  Future<File?> _download(String url) async {
    final http.Response response;
    try {
      response = await _httpClient.get(Uri.parse(url));
    } on http.ClientException {
      return null;
    } on SocketException {
      return null;
    }
    if (response.statusCode != 200) return null;

    await _svgDir.create(recursive: true);
    final file = _fileFor(url);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// Removes every cached SVG file.
  Future<void> clear() async {
    if (_svgDir.existsSync()) {
      await _svgDir.delete(recursive: true);
    }
  }
}
