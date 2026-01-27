import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/auth_repo.dart';
import 'presentation/app_shell.dart';

// Screen Imports
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
import 'presentation/screens/group/categories_screen.dart';
import 'presentation/screens/group/add_settlement_screen.dart';
import 'presentation/screens/group/group_settings_screen.dart';
import 'presentation/screens/personal/personal_home_screen.dart';
import 'presentation/screens/personal/add_personal_tx_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';

/// We pass AuthRepo here so the router can listen to auth state changes
GoRouter buildRouter(AuthRepo authRepo) {
  return GoRouter(
    initialLocation: '/splash',

    // This tells GoRouter to re-run the redirect logic whenever AuthRepo
    // calls notifyListeners() (which happens on login/logout).
    refreshListenable: authRepo,

    redirect: (context, state) {
      final isLoggedIn = authRepo.currentUser != null;
      final location = state.matchedLocation;

      final isAuthRoute = location.startsWith('/login') || location.startsWith('/register');
      final isSplash = location == '/splash';

      // 1. If we are on Splash, stay there until the app decides to move
      if (isSplash) return null;

      // 2. If not logged in and trying to access protected routes -> Go to Login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // 3. If logged in and trying to access Auth routes -> Go to Home
      if (isLoggedIn && isAuthRoute) {
        return '/app/groups';
      }

      // No redirect needed
      return null;
    },

    routes: [
      // Auth + Splash
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app shell (bottom nav tabs)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app/groups',
            name: 'groups',
            builder: (context, state) => const GroupsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'create_group',
                builder: (context, state) => const CreateGroupScreen(),
              ),
              GoRoute(
                path: 'join',
                name: 'join_group',
                builder: (context, state) => const JoinGroupScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/app/personal',
            name: 'personal',
            builder: (context, state) => const PersonalHomeScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add_personal_tx',
                builder: (context, state) => const AddPersonalTxScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/app/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Group-specific routes (pushed on top)
      GoRoute(
        path: '/group/:groupId',
        name: 'group_dashboard',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupDashboardScreen(groupId: groupId);
        },
        routes: [
          GoRoute(
            path: 'add',
            name: 'add_expense',
            builder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              return AddExpenseScreen(groupId: groupId);
            },
          ),
          GoRoute(
            path: 'approvals',
            name: 'approvals',
            builder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              return ApprovalsScreen(groupId: groupId);
            },
          ),
          GoRoute(
            path: 'members',
            name: 'group_members',
            builder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              return MembersScreen(groupId: groupId);
            },
          ),
          GoRoute(
            path: 'categories',
            name: 'categories',
            builder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              return CategoriesScreen(groupId: groupId);
            },
          ),
          GoRoute(
            path: 'settle',
            name: 'add_settlement',
            builder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              return AddSettlementScreen(groupId: groupId);
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
        ],
      ),
    ],
  );
}