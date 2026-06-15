import 'package:flutter/material.dart';

import '../../core/widgets/flick_keyboard/flick_kana_keyboard.dart';

/// Debug screen for previewing and exercising [FlickKanaKeyboard] in
/// isolation, without going through a review session.
///
/// Temporary scaffolding - remove once the keyboard is wired into the real
/// review flow behind a settings toggle.
class FlickKeyboardDemoScreen extends StatefulWidget {
  const FlickKeyboardDemoScreen({super.key});

  @override
  State<FlickKeyboardDemoScreen> createState() =>
      _FlickKeyboardDemoScreenState();
}

class _FlickKeyboardDemoScreenState extends State<FlickKeyboardDemoScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flick keyboard demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              readOnly: true,
              showCursor: true,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const Spacer(),
          FlickKanaKeyboard(
            controller: _controller,
            onCollapse: () => _showSnackBar('Collapse tapped'),
            onSubmit: () => _showSnackBar('Submit tapped: ${_controller.text}'),
          ),
        ],
      ),
    );
  }
}
