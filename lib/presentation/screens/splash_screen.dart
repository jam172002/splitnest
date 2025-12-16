import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/auth_repo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Let the first frame paint, then check auth.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final auth = context.read<AuthRepo>();
      final loggedIn = auth.currentUser != null;

      if (_navigated) return;
      _navigated = true;

      if (loggedIn) {
        context.go('/app/groups');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
