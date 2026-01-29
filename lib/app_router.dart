import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:splitnest/presentation/screens/splash_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/home/groups_screen.dart';
import '../presentation/screens/group/group_dashboard_screen.dart';
import '../presentation/screens/group/members_screen.dart';
import '../presentation/screens/group/group_settings_screen.dart';
import '../presentation/screens/group/add_expense_screen.dart';
import '../presentation/screens/group/add_settlement_screen.dart';
import '../presentation/screens/home/join_group_screen.dart';
import '../presentation/screens/home/create_group_screen.dart';
import '../presentation/screens/not_found_screen.dart'; // 👈 NEW IMPORT

final appRouter = GoRouter(
  initialLocation: '/splash',

  // 👇 THIS FIXES YOUR ERROR SCREEN
  errorBuilder: (context, state) => const NotFoundScreen(),

  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const GroupsScreen(),
      routes: [
        GoRoute(
          path: 'create-group',
          builder: (context, state) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: 'join-group',
          builder: (context, state) => const JoinGroupScreen(),
        ),
      ],
    ),

    // --- Group Specific Routes ---
    GoRoute(
      path: '/group/:groupId',
      name: 'group_dashboard',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return GroupDashboardScreen(groupId: groupId);
      },
      routes: [
        GoRoute(
          path: 'members',
          name: 'group_members',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            return MembersScreen(groupId: groupId);
          },
        ),
        GoRoute(
          path: 'settings',
          name: 'group_settings',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            return GroupSettingsScreen(groupId: groupId);
          },
        ),
        GoRoute(
          path: 'add-expense',
          name: 'add_expense',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            return AddExpenseScreen(groupId: groupId);
          },
        ),
        GoRoute(
          path: 'add-settlement',
          name: 'add_settlement',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            return AddSettlementScreen(groupId: groupId);
          },
        ),
      ],
    ),
  ],
);
