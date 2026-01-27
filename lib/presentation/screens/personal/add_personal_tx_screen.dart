import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../../data/personal_repo.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddPersonalTxScreen extends StatefulWidget {
  const AddPersonalTxScreen({super.key});

  @override
  State<AddPersonalTxScreen> createState() => _AddPersonalTxScreenState();
}

class _AddPersonalTxScreenState extends State<AddPersonalTxScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  bool _busy = false;
  String? _err;

  final List<String> _quickCategories = ['Groceries', 'Food', 'Transport', 'Rent', 'Medicine'];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final amt = double.tryParse(_amount.text.trim());
      if (amt == null || amt <= 0) throw Exception('Enter valid amount');
      if (_title.text.trim().isEmpty) throw Exception('Enter title');

      final uid = context.read<AuthRepo>().currentUser!.uid;
      await context.read<PersonalRepo>().addPersonal(
        uid: uid,
        amount: amt,
        title: _title.text.trim(),
        at: DateTime.now(),
      );

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Personal Expense',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Large Amount Input Section ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text('AMOUNT', style: theme.textTheme.labelLarge),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- Title Input ---
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Expense Title',
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'e.g. Weekly Groceries',
              ),
            ),
            const SizedBox(height: 16),

            // --- Quick Category Selection ---
            Text('Quick Select', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickCategories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(cat),
                    onPressed: () => setState(() => _title.text = cat),
                    backgroundColor: colorScheme.surfaceContainerLow,
                  ),
                )).toList(),
              ),
            ),

            const SizedBox(height: 40),

            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_err!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
              ),

            BusyButton(
                busy: _busy,
                onPressed: _save,
                text: 'Save Personal Expense'
            ),
          ],
        ),
      ),
    );
  }
}