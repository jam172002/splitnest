import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddIncomeScreen extends StatefulWidget {
  final String groupId;
  const AddIncomeScreen({super.key, required this.groupId});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  bool _busy = false;
  String? _err;

  bool _equalSplit = true;
  final Map<String, double> _custom = {}; // uid -> amount

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(Group group, bool isAdmin, List<GroupMember> members) async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      if (group.type != 'business') throw Exception('Income is only available in business groups.');

      final amt = double.tryParse(_amount.text.trim());
      if (amt == null || amt <= 0) throw Exception('Enter a valid amount');

      Map<String, double> dist = {};

      if (_equalSplit) {
        if (members.isEmpty) throw Exception('No members found');
        final per = amt / members.length;
        for (final m in members) {
          dist[m.id] = double.parse(per.toStringAsFixed(2));
        }
        // fix rounding remainder
        final sum = dist.values.fold<double>(0, (a, b) => a + b);
        final diff = double.parse((amt - sum).toStringAsFixed(2));
        if (diff.abs() > 0 && members.isNotEmpty) {
          dist[members.first.id] = double.parse((dist[members.first.id]! + diff).toStringAsFixed(2));
        }
      } else {
        dist = Map<String, double>.from(_custom);
        dist.removeWhere((k, v) => v <= 0);

        final sum = dist.values.fold<double>(0, (a, b) => a + b);
        if ((sum - amt).abs() > 0.01) {
          throw Exception('Custom distribution must equal total income.');
        }
      }

      final uid = context.read<AuthRepo>().currentUser!.uid;

      await context.read<GroupRepo>().addIncome(
        groupId: widget.groupId,
        group: group,
        amount: amt,
        distributeTo: dist,
        description: _note.text.trim().isEmpty ? null : _note.text.trim(),
        at: DateTime.now(),
        createdBy: uid,
        isAdmin: isAdmin,
      );

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
    final auth = context.read<AuthRepo>();
    final myId = auth.currentUser!.uid;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<Group>(
      stream: repo.watchGroup(widget.groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final group = groupSnap.data!;

        return FutureBuilder<String>(
          future: repo.roleOf(widget.groupId, myId),
          builder: (context, roleSnap) {
            final isAdmin = roleSnap.data == 'admin';

            return AppScaffold(
              title: 'Add Income',
              child: StreamBuilder<List<GroupMember>>(
                stream: repo.watchMembers(widget.groupId),
                builder: (context, membersSnap) {
                  final members = membersSnap.data ?? [];

                  // init custom distribution map once
                  for (final m in members) {
                    _custom.putIfAbsent(m.id, () => 0);
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Amount hero
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                            color: cs.primary.withValues(alpha: 0.08),
                          ),
                          child: Column(
                            children: [
                              Text('TOTAL INCOME', style: theme.textTheme.labelLarge),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _amount,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary,
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
                        const SizedBox(height: 12),

                        TextField(
                          controller: _note,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            prefixIcon: Icon(Icons.notes_rounded),
                            hintText: 'e.g. Client payment / Monthly revenue',
                          ),
                        ),

                        const SizedBox(height: 14),

                        // distribution mode
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                            color: cs.surface,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Distribution', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _equalSplit,
                                onChanged: (v) => setState(() => _equalSplit = v),
                                title: const Text('Equal split'),
                                subtitle: const Text('Divide income equally among members'),
                              ),
                              if (!_equalSplit) ...[
                                const SizedBox(height: 8),
                                ...members.map((m) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: TextField(
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: m.name,
                                        prefixIcon: const Icon(Icons.person_outline_rounded),
                                      ),
                                      onChanged: (v) {
                                        final d = double.tryParse(v.trim()) ?? 0;
                                        _custom[m.id] = d;
                                      },
                                    ),
                                  );
                                }).toList(),
                                Text(
                                  'Custom amounts must sum to total income.',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        if (_err != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(_err!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
                          ),

                        BusyButton(
                          busy: _busy,
                          onPressed: () => _save(group, isAdmin, members),
                          text: isAdmin && group.adminBypass ? 'Save (Auto-approved)' : 'Add Income',
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