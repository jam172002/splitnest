import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../personal/personal_display_controller.dart';
import '../../widgets/app_scaffold.dart';

class PersonalExpensesSettingsScreen extends StatelessWidget {
  const PersonalExpensesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final display = context.watch<PersonalDisplayController>();
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Personal Expenses',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Amount Privacy',
            style:
                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide/Show Amounts Button'),
            subtitle: const Text(
                'Show one button on the Personal Ledger to hide or '
                'reveal Balance, Income, Expense, Loans and Net together'),
            value: display.masterHideEnabled,
            onChanged: display.setMasterHideEnabled,
          ),
        ],
      ),
    );
  }
}
