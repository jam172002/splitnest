import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/app_bottom_nav.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  // Order MUST match the StatefulShellRoute branch order in app_router.dart:
  // 0 = Groups (/), 1 = Personal (/app/personal), 2 = Chat (/app/chat), 3 = Profile (/app/profile)
  static const _items = [
    AppBottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Groups',
    ),
    AppBottomNavItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Personal',
    ),
    AppBottomNavItem(
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
    ),
    AppBottomNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          navigationShell, // ← this replaces widget.child and enables state preservation
      bottomNavigationBar: AppBottomNav(
        selectedIndex: navigationShell.currentIndex,
        items: _items,
        onSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
