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
    return AppScaffold(
      title: 'Add Personal Expense',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title (e.g. Groceries)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 12),
          if (_err != null)
            Text(_err!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          BusyButton(busy: _busy, onPressed: _save, text: 'Save'),
        ],
      ),
    );
  }
}
