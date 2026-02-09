import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddEditBillScreen extends StatefulWidget {
  final String groupId;
  const AddEditBillScreen({super.key, required this.groupId});

  @override
  State<AddEditBillScreen> createState() => _AddEditBillScreenState();
}

class _AddEditBillScreenState extends State<AddEditBillScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _dueDay = TextEditingController(text: '1');

  bool _busy = false;
  String? _err;

  String? _editBillId;
  final Set<String> _participants = {};

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadEdit());
  }

  Future<void> _maybeLoadEdit() async {
    final billId = GoRouterState.of(context).uri.queryParameters['bill'];
    if (billId == null || billId.isEmpty) return;

    setState(() => _editBillId = billId);

    final repo = context.read<GroupRepo>();

    StreamSubscription<List<dynamic>>? sub;
    sub = repo.watchBills(widget.groupId).listen((list) {
      final b = list.where((e) => e.id == billId).cast<dynamic>().firstWhere(
            (e) => e != null,
        orElse: () => null,
      );

      if (b == null) return;

      if (!mounted) return;

      setState(() {
        _title.text = b.title;
        _amount.text = b.amount.toStringAsFixed(0);
        _dueDay.text = b.dueDay.toString();
        _participants
          ..clear()
          ..addAll(b.participants);
      });

      sub?.cancel();
    });
  }

  Future<void> _save(Group group, String uid) async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final title = _title.text.trim();
      final amt = double.tryParse(_amount.text.trim());
      final due = int.tryParse(_dueDay.text.trim());

      if (title.isEmpty) throw Exception('Enter bill title');
      if (amt == null || amt <= 0) throw Exception('Enter valid amount');
      if (due == null || due < 1 || due > 28) throw Exception('Due day must be between 1 and 28');
      if (_participants.isEmpty) throw Exception('Select at least one member');

      final repo = context.read<GroupRepo>();

      if (_editBillId != null) {
        await repo.updateBill(
          groupId: widget.groupId,
          billId: _editBillId!,
          title: title,
          amount: amt,
          dueDay: due,
          participants: _participants.toList(),
        );
      } else {
        await repo.addBill(
          groupId: widget.groupId,
          group: group,
          title: title,
          amount: amt,
          participants: _participants.toList(),
          dueDay: due,
          createdBy: uid,
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();
    final uid = context.read<AuthRepo>().currentUser!.uid;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<Group>(
      stream: repo.watchGroup(widget.groupId),
      builder: (context, gSnap) {
        if (!gSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final group = gSnap.data!;

        return AppScaffold(
          title: _editBillId == null ? 'Add Bill' : 'Edit Bill',
          child: StreamBuilder<List<GroupMember>>(
            stream: repo.watchMembers(widget.groupId),
            builder: (context, memSnap) {
              final members = memSnap.data ?? [];

              // default: select all for new bill
              if (_editBillId == null && _participants.isEmpty && members.isNotEmpty) {
                _participants.addAll(members.map((m) => m.id));
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Bill title',
                        prefixIcon: Icon(Icons.description_outlined),
                        hintText: 'e.g. Office rent',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _dueDay,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Due day',
                              prefixIcon: Icon(Icons.date_range_outlined),
                              hintText: '1-28',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text('Split between', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: members.map((m) {
                          final selected = _participants.contains(m.id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                v == true ? _participants.add(m.id) : _participants.remove(m.id);
                              });
                            },
                            title: Text(m.name, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                            secondary: CircleAvatar(child: Text(m.initials)),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_err != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_err!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
                      ),

                    BusyButton(
                      busy: _busy,
                      onPressed: () => _save(group, uid),
                      text: _editBillId == null ? 'Save Bill' : 'Update Bill',
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}