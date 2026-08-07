import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'data/chat_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationsRepo = NotificationsRepo();
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid != null) {
    await notificationsRepo.initAndSaveToken(currentUid);
  }

  runApp(SplitNestApp(notificationsRepo: notificationsRepo));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notificationsRepo.configureMessageNavigation(appRouter.go);
  });
}

class SplitNestApp extends StatelessWidget {
  final NotificationsRepo notificationsRepo;

  const SplitNestApp({
    super.key,
    required this.notificationsRepo,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthRepo()),
        ChangeNotifierProvider(create: (_) => ThemeModeController()),
        ChangeNotifierProvider(create: (_) => PersonalLockController()),
        Provider(create: (_) => GroupRepo()),
        Provider(create: (_) => PersonalRepo()),
        Provider(create: (_) => ChatRepo()),
        Provider.value(value: notificationsRepo),
      ],
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<ThemeModeController>().mode;

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'SplitNest',
            routerConfig: appRouter,

            // Theme logic stays here only as "use theme from theme.dart"
            themeMode: themeMode,
            theme: AppTheme.light(context),
            darkTheme: AppTheme.dark(context),
          );
        },
      ),
    );
  }
}
