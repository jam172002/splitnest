import 'package:flutter/material.dart';

class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String text;

  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : Text(text),
    );
  }
}
