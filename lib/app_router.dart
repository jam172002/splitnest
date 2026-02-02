import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:splitnest/presentation/screens/auth/register_screen.dart';
import 'package:splitnest/presentation/screens/personal/add_personal_tx_screen.dart';

import 'data/auth_repo.dart';
import '../presentation/app_shell.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/group/add_expense_screen.dart';
import '../presentation/screens/group/add_settlement_screen.dart';
import '../presentation/screens/group/group_dashboard_screen.dart';
import '../presentation/screens/group/group_settings_screen.dart';
import '../presentation/screens/group/members_screen.dart';
import '../presentation/screens/home/create_group_screen.dart';
import '../presentation/screens/home/groups_screen.dart';
import '../presentation/screens/home/join_group_screen.dart';
import '../presentation/screens/personal/personal_home_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/not_found_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: true, // helpful during development

  // Custom 404 screen
  errorBuilder: (context, state) => const NotFoundScreen(),

  redirect: (BuildContext context, GoRouterState state) {
    final location = state.uri.path;  // better than toString()
    final authRepo = Provider.of<AuthRepo>(context, listen: false);
    final isLoggedIn = authRepo.currentUser != null;

    // 1. Splash handling
    if (location.startsWith('/splash')) {
      return isLoggedIn ? '/' : '/login';
    }

    // 2. Explicitly allow public auth routes
    final publicAuthPaths = ['/login', '/register'];
    if (publicAuthPaths.contains(location)) {
      if (isLoggedIn) {
        return '/'; // already logged in → go home
      }
      return null; // allow access
    }

    // 3. Protect all other app routes
    if (!isLoggedIn) {
      return '/login';
    }

    // 4. If logged in and trying to access auth pages → already handled above
    return null;
  },
  routes: [
    // Public routes
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // ───────────────────────────────────────────────────────────────
    // Main authenticated shell with bottom navigation
    // ───────────────────────────────────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0 ── Groups Tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const GroupsScreen(),
              routes: [
                GoRoute(
                  path: 'create-group',
                  name: 'create_group',
                  builder: (context, state) => const CreateGroupScreen(),
                ),
                GoRoute(
                  path: 'join-group',
                  name: 'join_group',
                  builder: (context, state) => const JoinGroupScreen(),
                ),
              ],
            ),

            // Group detail + nested routes
            GoRoute(
              path: '/group/:groupId',
              name: 'group_dashboard',
              builder: (context, state) => GroupDashboardScreen(
                groupId: state.pathParameters['groupId']!,
              ),
              routes: [
                GoRoute(
                  path: 'members',
                  name: 'group_members',
                  builder: (context, state) => MembersScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
                GoRoute(
                  path: 'settings',
                  name: 'group_settings',
                  builder: (context, state) => GroupSettingsScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
                GoRoute(
                  path: 'add-expense',
                  name: 'add_expense',
                  builder: (context, state) => AddExpenseScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
                GoRoute(
                  path: 'add-settlement',
                  name: 'add_settlement',
                  builder: (context, state) => AddSettlementScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Branch 1 ── Personal Tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/personal',
              builder: (context, state) => const PersonalHomeScreen(),
              routes: [
                // Missing route — now added
                GoRoute(
                  path: 'add',
                  name: 'add_personal_expense',
                  builder: (context, state) => const AddPersonalTxScreen(),
                ),
              ],
            ),
          ],
        ),

        // Branch 2 ── Profile Tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);