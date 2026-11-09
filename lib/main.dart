import 'package:flutter/material.dart';

void main() {
  runApp(const IwardrobeApp());
}

/// Placeholder root widget (task 001 — project scaffolding).
///
/// The real entry point (bootstrap, provider DI tree, `go_router` router,
/// adaptive shell) arrives in task 013.
class IwardrobeApp extends StatelessWidget {
  const IwardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iWardrobe',
      home: const Scaffold(body: Center(child: Text('iWardrobe (scaffold)'))),
    );
  }
}
