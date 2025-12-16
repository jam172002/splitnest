import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amount = TextEditingController();
  String _category = 'breakfast';
  String? _paidBy;
  final Set<String> _participants = {};

  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save({required Group group, required bool isAdmin}) async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final amt = double.tryParse(_amount.text.trim());
      if (amt == null || amt <= 0) throw Exception('Enter valid amount');
      if (_paidBy == null) throw Exception('Select money provider (paid by)');
      if (_participants.isEmpty) throw Exception('Select participants');

      final myUid = context.read<AuthRepo>().currentUser!.uid;

      await context.read<GroupRepo>().addExpense(
        groupId: widget.groupId,
        group: group,
        amount: amt,
        category: _category,
        paidBy: _paidBy!,
        participants: _participants.toList(),
        at: DateTime.now(),
        createdBy: myUid,
        isAdmin: isAdmin,
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

    return StreamBuilder<Group>(
      stream: repo.watchGroup(widget.groupId),
      builder: (context, groupSnap) {
        final group = groupSnap.data;
        if (group == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return FutureBuilder<String>(
          future: repo.roleOf(widget.groupId, myUid),
          builder: (context, roleSnap) {
            final role = roleSnap.data ?? 'member';
            final isAdmin = role == 'admin';

            return AppScaffold(
              title: 'Add Expense',
              child: StreamBuilder<List<GroupMember>>(
                stream: repo.watchMembers(widget.groupId),
                builder: (context, memSnap) {
                  final members = memSnap.data ?? [];
                  if (members.isNotEmpty && _paidBy == null) {
                    _paidBy = myUid;
                    _participants.add(myUid);
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount', hintText: 'e.g 800'),
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<List<String>>(
                          stream: repo.watchCategories(widget.groupId),
                          builder: (context, catSnap) {
                            final cats = catSnap.data ?? ['breakfast', 'lunch', 'dinner'];
                            if (!cats.contains(_category)) _category = cats.first;
                            return DropdownButtonFormField<String>(
                              value: _category,
                              items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => _category = v ?? _category),
                              decoration: const InputDecoration(labelText: 'Expense type'),
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _paidBy,
                          items: members.map((m) => DropdownMenuItem(value: m.uid, child: Text(m.email))).toList(),
                          onChanged: (v) => setState(() => _paidBy = v),
                          decoration: const InputDecoration(labelText: 'Money provider (paid by)'),
                        ),

                        const SizedBox(height: 16),
                        Text('Participants', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),

                        ...members.map((m) {
                          final selected = _participants.contains(m.uid);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _participants.add(m.uid);
                                } else {
                                  _participants.remove(m.uid);
                                }
                              });
                            },
                            title: Text(m.email),
                            subtitle: Text(m.role),
                          );
                        }),

                        const SizedBox(height: 8),
                        if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),

                        BusyButton(
                          busy: _busy,
                          onPressed: () => _save(group: group, isAdmin: isAdmin),
                          text: (isAdmin && group.adminBypass)
                              ? 'Save (Auto-approved)'
                              : (group.requireApproval ? 'Save (Pending Approval)' : 'Save (Approved)'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
