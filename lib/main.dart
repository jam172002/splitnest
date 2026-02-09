import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:splitnest/presentation/screens/personal/personal_lock_controller.dart';
import 'package:splitnest/theme/theme.dart';
import 'package:splitnest/theme/theme_mode_controller.dart';

import 'firebase_options.dart';
import 'app_router.dart';

import 'data/auth_repo.dart';
import 'data/group_repo.dart';
import 'data/personal_repo.dart';
import 'data/notifications_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SplitNestApp());
}

class SplitNestApp extends StatelessWidget {
  const SplitNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthRepo()),
        ChangeNotifierProvider(create: (_) => ThemeModeController()),
        ChangeNotifierProvider(create: (_) => PersonalLockController()),
        Provider(create: (_) => GroupRepo()),
        Provider(create: (_) => PersonalRepo()),
        Provider(create: (_) => NotificationsRepo()),
      ],
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<ThemeModeController>().mode;

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'SplitNest',
            routerConfig: appRouter,

            // ✅ Theme logic stays here only as "use theme from theme.dart"
            themeMode: themeMode,
            theme: AppTheme.light(context),
            darkTheme: AppTheme.dark(context),
          );
        },
      ),
    );
  }
}