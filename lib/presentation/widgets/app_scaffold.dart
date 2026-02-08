import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  /// ✅ NEW: custom title widget (for clickable WhatsApp-like title)
  final Widget? titleWidget;

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
  final bool isScrollable;

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
    this.titleWidget, // ✅ NEW
    this.actions,
    this.centerTitle = false,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.padding,
    this.useSafeArea = true,
    this.backgroundColor,
    this.isScrollable = false,
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

    if (padding != null) {
      bodyContent = Padding(padding: padding!, child: bodyContent);
    }

    if (isScrollable || scrollController != null) {
      bodyContent = SingleChildScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: bodyContent,
      );
    }

    if (useSafeArea) {
      bodyContent = SafeArea(child: bodyContent);
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: AppBar(
        title: titleWidget ??
            Text(
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
        elevation: 0,
        scrolledUnderElevation: 3,
        surfaceTintColor: colorScheme.surfaceTint,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      drawer: drawer,
      endDrawer: endDrawer,
      body: bodyContent,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation:
      floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
      resizeToAvoidBottomInset: true,
    );
  }

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