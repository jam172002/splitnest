import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indexFromLoc(String loc) {
    if (loc.startsWith('/app/personal')) return 1;
    if (loc.startsWith('/app/profile')) return 2;
    return 0;
  }

  void _go(int i) {
    switch (i) {
      case 0:
        context.go('/app/groups');
        break;
      case 1:
        context.go('/app/personal');
        break;
      case 2:
        context.go('/app/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final index = _indexFromLoc(loc);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Personal'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Profile'),
        ],
      ),
    );
  }
}
