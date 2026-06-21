import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/cache/cache_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cacheDirectory = await resolveCacheDirectory();

  runApp(
    ProviderScope(
      overrides: [cacheDirectoryProvider.overrideWithValue(cacheDirectory)],
      child: const HajikuApp(),
    ),
  );
}
