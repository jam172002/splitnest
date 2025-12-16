import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'app_router.dart';
import 'data/auth_repo.dart';
import 'data/group_repo.dart';
import 'data/personal_repo.dart';

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
        Provider(create: (_) => AuthRepo()),
        Provider(create: (_) => GroupRepo()),
        Provider(create: (_) => PersonalRepo()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'SplitNest',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepPurple,
        ),
        routerConfig: buildRouter(),
      ),
    );
  }
}
