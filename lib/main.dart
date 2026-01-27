import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

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
    // Shared button styles to avoid using Theme.of(context) inside the constructor
    final sharedFilledButtonStyle = FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      minimumSize: const Size(0, 52),
      elevation: 0,
    );

    final sharedOutlinedButtonStyle = OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      minimumSize: const Size(0, 52),
    );

    final sharedTextButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return MultiProvider(
      providers: [
        // Changed to ChangeNotifierProvider so the UI/Router can listen to Auth changes
        ChangeNotifierProvider(create: (_) => AuthRepo()),
        Provider(create: (_) => GroupRepo()),
        Provider(create: (_) => PersonalRepo()),
        Provider(create: (_) => NotificationsRepo()),
      ],
      // We use a Builder here to get a context that has access to the Providers above
      child: Builder(
        builder: (context) {
          final authRepo = context.read<AuthRepo>();

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'SplitNest',

            // Pass the authRepo to the router for reactive redirects
            routerConfig: buildRouter(authRepo),

            themeMode: ThemeMode.system,

            // ────────────────────────────────────────────────
            //            Modern Material 3 Theme (Light)
            // ────────────────────────────────────────────────
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
                primary: Colors.deepPurple.shade700,
                surface: Colors.grey.shade50,
                surfaceContainerLowest: Colors.white,
                surfaceContainerLow: Colors.grey.shade50,
                surfaceContainer: Colors.grey.shade100,
                surfaceContainerHigh: Colors.grey.shade200,
              ),

              cardTheme: CardThemeData(
                elevation: 1,
                shadowColor: Colors.black.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              ),

              filledButtonTheme: FilledButtonThemeData(style: sharedFilledButtonStyle),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: sharedOutlinedButtonStyle.copyWith(
                  side: WidgetStateProperty.all(BorderSide(color: Colors.deepPurple.shade300)),
                ),
              ),
              textButtonTheme: TextButtonThemeData(style: sharedTextButtonStyle),

              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),

              appBarTheme: const AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 1,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                centerTitle: false,
                titleTextStyle: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: Colors.black,
                ),
              ),

              textTheme: const TextTheme(
                headlineLarge: TextStyle(fontSize: 32, height: 1.25),
                headlineMedium: TextStyle(fontSize: 28, height: 1.28),
                headlineSmall: TextStyle(fontSize: 24, height: 1.33),
                titleLarge: TextStyle(fontSize: 22, height: 1.27, fontWeight: FontWeight.w600),
                titleMedium: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600),
                titleSmall: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w600),
                bodyLarge: TextStyle(fontSize: 16, height: 1.5),
                bodyMedium: TextStyle(fontSize: 14, height: 1.43),
                labelLarge: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w500),
              ),

              navigationBarTheme: NavigationBarThemeData(
                height: 80,
                indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              ),
            ),

            // ────────────────────────────────────────────────
            //            Modern Material 3 Theme (Dark)
            // ────────────────────────────────────────────────
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
                primary: Colors.deepPurple.shade300,
                surface: const Color(0xFF121212),
                surfaceContainerLowest: const Color(0xFF0E0E0E),
                surfaceContainerLow: const Color(0xFF1A1A1A),
                surfaceContainer: const Color(0xFF222222),
                surfaceContainerHigh: const Color(0xFF2A2A2A),
              ),

              cardTheme: CardThemeData(
                elevation: 1,
                shadowColor: Colors.black.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
              ),

              filledButtonTheme: FilledButtonThemeData(style: sharedFilledButtonStyle),
              outlinedButtonTheme: OutlinedButtonThemeData(style: sharedOutlinedButtonStyle),
              textButtonTheme: TextButtonThemeData(style: sharedTextButtonStyle),

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
                ),
              ),

              appBarTheme: const AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 1,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }
}