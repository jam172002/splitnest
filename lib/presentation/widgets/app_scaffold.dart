import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  /// Changed from FloatingActionButton? to Widget?
  final Widget? fab;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.fab,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: fab, // now accepts Column or anything
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
