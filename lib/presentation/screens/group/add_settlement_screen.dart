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
      if (amt == null || amt <= 0) throw Exception('Enter a valid amount');
      if (_from == null || _to == null) throw Exception('Select both members');
      if (_from == _to) throw Exception('Members must be different');

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
      setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repo = context.read<GroupRepo>();
    final myUid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Settle Balance',
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(widget.groupId),
        builder: (context, snap) {
          final members = snap.data ?? [];
          if (members.isEmpty) return const Center(child: CircularProgressIndicator());

          _from ??= myUid;
          // Set _to to the first member who isn't the 'from' person
          _to ??= members.firstWhere((m) => m.id != _from, orElse: () => members.first).id;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Amount Hero Section ---
                Text(
                  "Amount to Settle",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                ),
                TextField(
                  controller: _amount,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: 'PKR ',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 32),

                // --- Transfer Visualization ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _buildMemberDropdown(
                        label: 'From (Payer)',
                        value: _from,
                        members: members,
                        onChanged: (v) => setState(() => _from = v),
                        theme: theme,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.arrow_downward_rounded, color: colorScheme.primary),
                        ),
                      ),
                      _buildMemberDropdown(
                        label: 'To (Receiver)',
                        value: _to,
                        members: members,
                        onChanged: (v) => setState(() => _to = v),
                        theme: theme,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                if (_err != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      _err!,
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                BusyButton(
                  busy: _busy,
                  onPressed: _save,
                  text: 'Confirm Settlement',
                ),
              ],
            ),
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
    required ThemeData theme,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.person_outline_rounded),
        border: const OutlineInputBorder(),
      ),
      items: members.map((m) => DropdownMenuItem(
        value: m.id,
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              child: Text(m.initials, style: const TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 10),
            Text(m.name),
          ],
        ),
      )).toList(),
      onChanged: onChanged,
    );
  }
}