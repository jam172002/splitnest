import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/expense_calculator.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddSettlementScreen extends StatefulWidget {
  final String groupId;
  final String? initialFromUid;
  final String? initialToUid;

  const AddSettlementScreen({
    super.key,
    required this.groupId,
    this.initialFromUid,
    this.initialToUid,
  });

  @override
  State<AddSettlementScreen> createState() => _AddSettlementScreenState();
}

class _AddSettlementScreenState extends State<AddSettlementScreen> {
  final _amount = TextEditingController();
  late String _selectedGroupId;
  String? _from;
  String? _to;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _from = widget.initialFromUid;
    _to = widget.initialToUid;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(double outstanding) async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final amount = double.tryParse(_amount.text.trim());
      if (amount == null || amount <= 0) {
        throw Exception('Enter a valid amount');
      }
      if (_from == null || _to == null) {
        throw Exception('Select both members');
      }
      if (_from == _to) {
        throw Exception('Members must be different');
      }
      if (outstanding <= 0.005) {
        throw Exception('There is no outstanding payment in this direction');
      }
      if (amount - outstanding > 0.01) {
        throw Exception(
          'Payment cannot exceed ${Fmt.money(outstanding)}',
        );
      }

      final uid = context.read<AuthRepo>().currentUser!.uid;
      await context.read<GroupRepo>().addSettlement(
            groupId: _selectedGroupId,
            amount: amount,
            fromUid: _from!,
            toUid: _to!,
            createdBy: uid,
          );

      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _err = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final repo = context.read<GroupRepo>();
    final myUid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Settle Balance',
      child: StreamBuilder<List<Group>>(
        stream: repo.watchMyGroups(myUid),
        builder: (context, groupSnapshot) {
          final groups = groupSnapshot.data ?? [];
          if (groups.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (groups.every((group) => group.id != _selectedGroupId)) {
            _selectedGroupId = groups.first.id;
          }

          return StreamBuilder<List<GroupMember>>(
            stream: repo.watchMembers(_selectedGroupId),
            builder: (context, memberSnapshot) {
              final members = memberSnapshot.data ?? [];
              if (members.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final memberIds = members.map((member) => member.id).toSet();
              if (_from == null || !memberIds.contains(_from)) {
                _from = memberIds.contains(myUid) ? myUid : members.first.id;
              }
              if (_to == null || !memberIds.contains(_to) || _to == _from) {
                final receivers =
                    members.where((member) => member.id != _from).toList();
                _to = receivers.isEmpty ? null : receivers.first.id;
              }

              final mutualGroups = groups.where((group) {
                return _from != null &&
                    _to != null &&
                    group.memberUids.contains(_from) &&
                    group.memberUids.contains(_to);
              }).toList();

              return StreamBuilder<List<GroupTx>>(
                stream: repo.watchTx(_selectedGroupId),
                builder: (context, txSnapshot) {
                  final transactions = txSnapshot.data ?? [];
                  final netByMember = ExpenseCalculator.calculateNetByMember(
                    txs: transactions,
                    memberUids: members.map((member) => member.id).toList(),
                  );
                  final outstanding = _from == null || _to == null
                      ? 0.0
                      : ExpenseCalculator.outstandingBetween(
                          netByMember: netByMember,
                          fromUid: _from!,
                          toUid: _to!,
                        );
                  final enteredAmount =
                      double.tryParse(_amount.text.trim()) ?? 0;
                  final remaining = outstanding > enteredAmount
                      ? outstanding - enteredAmount
                      : 0.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mutualGroups.isNotEmpty)
                          DropdownButtonFormField<String>(
                            key: ValueKey(_selectedGroupId),
                            initialValue: _selectedGroupId,
                            decoration: const InputDecoration(
                              labelText: 'Settle in group',
                              prefixIcon: Icon(Icons.groups_outlined),
                            ),
                            items: mutualGroups
                                .map(
                                  (group) => DropdownMenuItem(
                                    value: group.id,
                                    child: Text(group.name),
                                  ),
                                )
                                .toList(),
                            onChanged: mutualGroups.length <= 1
                                ? null
                                : (groupId) {
                                    if (groupId == null) return;
                                    setState(() {
                                      _selectedGroupId = groupId;
                                      _err = null;
                                    });
                                  },
                          ),
                        if (mutualGroups.length > 1) ...[
                          const SizedBox(height: 8),
                          Text(
                            'These members share ${mutualGroups.length} groups. Select which group this payment belongs to.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              _buildMemberDropdown(
                                label: 'From (Payer)',
                                value: _from,
                                members: members,
                                onChanged: (value) {
                                  setState(() {
                                    _from = value;
                                    if (_to == value) _to = null;
                                    _amount.clear();
                                    _err = null;
                                  });
                                },
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: colors.primaryContainer,
                                  child: Icon(
                                    Icons.arrow_downward_rounded,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                              _buildMemberDropdown(
                                label: 'To (Receiver)',
                                value: _to,
                                members: members,
                                onChanged: (value) {
                                  setState(() {
                                    _to = value;
                                    if (_from == value) _from = null;
                                    _amount.clear();
                                    _err = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                colors.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _BalanceValue(
                                  label: 'Outstanding',
                                  value: Fmt.money(outstanding),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 42,
                                color: colors.outlineVariant,
                              ),
                              Expanded(
                                child: _BalanceValue(
                                  label: 'After payment',
                                  value: Fmt.money(remaining),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Amount to pay',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        TextField(
                          controller: _amount,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          enabled: outstanding > 0.005,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() => _err = null),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            prefixText: 'PKR ',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                        if (outstanding <= 0.005)
                          Text(
                            'No payment is due from the selected payer to the receiver in this group.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        if (_err != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _err!,
                            style: TextStyle(color: colors.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        BusyButton(
                          busy: _busy,
                          onPressed: outstanding <= 0.005
                              ? null
                              : () => _save(outstanding),
                          text: 'Confirm Payment',
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMemberDropdown({
    required String label,
    required String? value,
    required List<GroupMember> members,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-$_selectedGroupId'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.person_outline_rounded),
      ),
      items: members
          .map(
            (member) => DropdownMenuItem(
              value: member.id,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text(
                      member.initials,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      member.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _BalanceValue extends StatelessWidget {
  final String label;
  final String value;

  const _BalanceValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
