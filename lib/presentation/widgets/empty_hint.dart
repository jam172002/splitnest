import 'package:flutter/material.dart';

class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.grey[600],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
