import 'package:flutter/material.dart';

class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon; // ← NEW: Support for icons
  final ButtonStyle? style;

  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.text,
    this.icon,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // We determine the loader color based on the button's foreground color
    final loaderColor = style?.foregroundColor?.resolve({}) ?? colorScheme.onPrimary;

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: style ?? FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: busy
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(loaderColor),
            strokeCap: StrokeCap.round,
          ),
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}