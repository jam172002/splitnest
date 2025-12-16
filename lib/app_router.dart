import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/auth_repo.dart';
import 'presentation/app_shell.dart';

import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';

import 'presentation/screens/home/groups_screen.dart';
import 'presentation/screens/home/create_group_screen.dart';
import 'presentation/screens/home/join_group_screen.dart';

import 'presentation/screens/group/group_dashboard_screen.dart';
import 'presentation/screens/group/add_expense_screen.dart';
import 'presentation/screens/group/approvals_screen.dart';
import 'presentation/screens/group/members_screen.dart';

import 'presentation/screens/personal/personal_home_screen.dart';
import 'presentation/screens/personal/add_personal_tx_screen.dart';

import 'presentation/screens/profile/profile_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = context.read<AuthRepo>();
      final loggedIn = auth.currentUser != null;

      final loc = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/login') || loc.startsWith('/register');
      final isSplash = loc == '/splash';

      if (isSplash) return null;

      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute) return '/app/groups';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app/groups',
            builder: (_, __) => const GroupsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const CreateGroupScreen(),
              ),
              GoRoute(
                path: 'join',
                builder: (_, __) => const JoinGroupScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/app/personal',
            builder: (_, __) => const PersonalHomeScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const AddPersonalTxScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/app/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // Group routes (not inside shell tabs so we can push from any tab)
      GoRoute(
        path: '/group/:gid',
        builder: (context, state) {
          final gid = state.pathParameters['gid']!;
          return GroupDashboardScreen(groupId: gid);
        },
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final gid = state.pathParameters['gid']!;
              return AddExpenseScreen(groupId: gid);
            },
          ),
          GoRoute(
            path: 'approvals',
            builder: (context, state) {
              final gid = state.pathParameters['gid']!;
              return ApprovalsScreen(groupId: gid);
            },
          ),
          GoRoute(
            path: 'members',
            builder: (context, state) {
              final gid = state.pathParameters['gid']!;
              return MembersScreen(groupId: gid);
            },
          ),
        ],
      ),
    ],
  );
}
