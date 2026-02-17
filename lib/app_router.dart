import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:splitnest/presentation/screens/auth/register_screen.dart';
import 'package:splitnest/presentation/screens/group/add_edit_bill_screen.dart';
import 'package:splitnest/presentation/screens/group/add_income_screen.dart';
import 'package:splitnest/presentation/screens/group/bills_screen.dart';
import 'package:splitnest/presentation/screens/group/group_combined_screen.dart';
import 'package:splitnest/presentation/screens/group/group_info_screen.dart';
import 'package:splitnest/presentation/screens/group/group_tx_detail_screen.dart';
import 'package:splitnest/presentation/screens/personal/add_personal_tx_screen.dart';
import 'package:splitnest/presentation/screens/personal/personal_lock_wrapper.dart';

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
  debugLogDiagnostics: true,
  errorBuilder: (context, state) => const NotFoundScreen(),

  redirect: (BuildContext context, GoRouterState state) {
    final location = state.uri.path;
    final authRepo = Provider.of<AuthRepo>(context, listen: false);
    final isLoggedIn = authRepo.currentUser != null;

    if (location.startsWith('/splash')) {
      return isLoggedIn ? '/' : '/login';
    }

    final publicAuthPaths = ['/login', '/register'];
    if (publicAuthPaths.contains(location)) {
      if (isLoggedIn) return '/';
      return null;
    }

    if (!isLoggedIn) return '/login';
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

    GoRoute(
      path: '/group/:groupId/tx/:txId',
      builder: (context, state) => GroupTxDetailScreen(
        groupId: state.pathParameters['groupId']!,
        txId: state.pathParameters['txId']!,
      ),
    ),

    GoRoute(
      path: '/group/:groupId/combined',
      builder: (context, state) => GroupCombinedScreen(
        groupId: state.pathParameters['groupId']!,
      ),
    ),

    // ✅ Shell should contain ONLY 3 tab root screens
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const GroupsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/personal',
              builder: (context, state) => const PersonalLockWrapper(
                child: PersonalHomeScreen(),
              ),
            ),
          ],
        ),
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

    // ✅ EVERYTHING ELSE OUTSIDE SHELL (no bottom bar)

    GoRoute(
      path: '/create-group',
      name: 'create_group',
      builder: (context, state) => const CreateGroupScreen(),
    ),
    GoRoute(
      path: '/join-group',
      name: 'join_group',
      builder: (context, state) => const JoinGroupScreen(),
    ),

    GoRoute(
      path: '/group/:groupId',
      name: 'group_dashboard',
      builder: (context, state) => GroupDashboardScreen(
        groupId: state.pathParameters['groupId']!,
      ),
      routes: [
        GoRoute(
          path: 'add-income',
          name: 'add_income',
          builder: (context, state) => AddIncomeScreen(
            groupId: state.pathParameters['groupId']!,
          ),
        ),
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
    GoRoute(
      path: 'bills',
      builder: (context, state) => BillsScreen(
        groupId: state.pathParameters['groupId']!,
      ),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => AddEditBillScreen(
            groupId: state.pathParameters['groupId']!,
          ),
        ),
        GoRoute(
          path: 'edit',
          builder: (context, state) => AddEditBillScreen(
            groupId: state.pathParameters['groupId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/app/personal/add',
      name: 'add_personal_expense',
      builder: (context, state) => const AddPersonalTxScreen(),
    ),

    GoRoute(
      path: '/group/:groupId/info',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return GroupInfoScreen(groupId: groupId);
      },
    ),
  ],
);