import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/auth_repo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup a simple fade-in animation for the logo
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // 2. Logic to check auth status
    _initApp();
  }

  Future<void> _initApp() async {
    // Give the animation a moment to breathe (minimum 2 seconds splash)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final auth = context.read<AuthRepo>();
    final loggedIn = auth.currentUser != null;

    if (loggedIn) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Gradient background for a premium feel
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Your App Icon / Logo
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Icon(
                  Icons.home_rounded, // Using your brand icon
                  size: 80,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              Text(
                'SplitNest',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Smarter sharing for your home',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 64),

              // Loading Indicator
              SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Syncing...',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}