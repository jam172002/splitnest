import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  /// AppBar related
  final List<Widget>? actions;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  /// Body related
  final EdgeInsets? padding;
  final bool useSafeArea;
  final Color? backgroundColor;
  final bool isScrollable; // ← NEW: Automatically handle scrolling

  /// FAB related
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;

  /// Drawer / EndDrawer
  final Widget? drawer;
  final Widget? endDrawer;

  /// Optional: custom scroll behavior
  final ScrollController? scrollController;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.centerTitle = false, // ← M3 standard often prefers left-aligned
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.padding,
    this.useSafeArea = true,
    this.backgroundColor,
    this.isScrollable = false, // Default to false to avoid double-scroll issues
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = false,
    this.drawer,
    this.endDrawer,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget bodyContent = child;

    // Apply padding
    if (padding != null) {
      bodyContent = Padding(padding: padding!, child: bodyContent);
    }

    // Wrap in scroll view if requested or if a controller is provided
    if (isScrollable || scrollController != null) {
      bodyContent = SingleChildScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: bodyContent,
      );
    }

    // Wrap with SafeArea
    if (useSafeArea) {
      bodyContent = SafeArea(child: bodyContent);
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,

      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: centerTitle,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        bottom: bottom,

        // --- Material 3 Visuals ---
        elevation: 0,
        scrolledUnderElevation: 3,
        surfaceTintColor: colorScheme.surfaceTint,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),

      drawer: drawer,
      endDrawer: endDrawer,
      body: bodyContent,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
      resizeToAvoidBottomInset: true,
    );
  }

  // Convenience Factory for Scrollable Screens (like Settings or Forms)
  factory AppScaffold.scrollable({
    required String title,
    required Widget child,
    List<Widget>? actions,
    Widget? fab,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) =>
      AppScaffold(
        title: title,
        child: child,
        actions: actions,
        floatingActionButton: fab,
        padding: padding,
        isScrollable: true,
      );
}