import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Creates (if needed) and returns the root directory for Hajiku's on-device
/// caches, under the platform's application-support directory.
Future<Directory> resolveCacheDirectory() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}hajiku_cache');
  await dir.create(recursive: true);
  return dir;
}

/// The cache root directory. Resolved once in `main()` and supplied via an
/// override, so the rest of the app can read it synchronously. Tests override
/// it with a temporary directory.
final cacheDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError(
    'cacheDirectoryProvider must be overridden with a resolved directory',
  ),
);
