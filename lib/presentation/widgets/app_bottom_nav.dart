import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Floating pill-shaped bottom nav bar. The selected item is rendered as a
/// larger circular badge (primary green, popped above the bar) while the
/// rest stay as plain outline icons — no labels shown.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<AppBottomNavItem> items;
  final ValueChanged<int> onSelected;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      top: false,
      child: SizedBox(
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.card(isDark),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _NavIcon(
                        item: items[i],
                        selected: i == selectedIndex,
                        isDark: isDark,
                        onTap: () => onSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final AppBottomNavItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavIcon({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor = AppColors.subText(isDark);

    return Semantics(
      label: item.label,
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 64,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            offset: selected ? const Offset(0, -0.22) : Offset.zero,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: selected ? 52 : 40,
                height: selected ? 52 : 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.green : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? AppColors.white : unselectedColor,
                  size: selected ? 26 : 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
