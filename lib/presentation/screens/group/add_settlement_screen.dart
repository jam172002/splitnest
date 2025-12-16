import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddSettlementScreen extends StatefulWidget {
  final String groupId;
  const AddSettlementScreen({super.key, required this.groupId});

  @override
  State<AddSettlementScreen> createState() => _AddSettlementScreenState();
}

class _AddSettlementScreenState extends State<AddSettlementScreen> {
  final _amount = TextEditingController();
  String? _from;
  String? _to;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
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
      if (_from == null || _to == null) throw Exception('Select from/to');
      if (_from == _to) throw Exception('From and To cannot be same');

      final uid = context.read<AuthRepo>().currentUser!.uid;

      await context.read<GroupRepo>().addSettlement(
        groupId: widget.groupId,
        amount: amt,
        fromUid: _from!,
        toUid: _to!,
        createdBy: uid,
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
    final repo = context.read<GroupRepo>();
    final myUid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Add Settlement',
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(widget.groupId),
        builder: (context, snap) {
          final members = snap.data ?? [];

          _from ??= myUid;
          _to ??= (members.isNotEmpty ? members.first.uid : null);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (paid to settle)'),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _from,
                items: members.map((m) => DropdownMenuItem(value: m.uid, child: Text(m.email))).toList(),
                onChanged: (v) => setState(() => _from = v),
                decoration: const InputDecoration(labelText: 'From (payer)'),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _to,
                items: members.map((m) => DropdownMenuItem(value: m.uid, child: Text(m.email))).toList(),
                onChanged: (v) => setState(() => _to = v),
                decoration: const InputDecoration(labelText: 'To (receiver)'),
              ),

              const SizedBox(height: 12),
              if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),

              BusyButton(busy: _busy, onPressed: _save, text: 'Save Settlement'),
            ],
          );
        },
      ),
    );
  }
}
