import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class HajikuApp extends StatelessWidget {
  const HajikuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hajiku',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('弾く Hajiku')));
  }
}
