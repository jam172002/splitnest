import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';

class GroupTransactionHistoryScreen extends StatefulWidget {
  final String groupId;

  const GroupTransactionHistoryScreen({super.key, required this.groupId});

  @override
  State<GroupTransactionHistoryScreen> createState() =>
      _GroupTransactionHistoryScreenState();
}

class _GroupTransactionHistoryScreenState
    extends State<GroupTransactionHistoryScreen> {
  String? payerFilterUid;
  String? participantFilterUid;

  void _clearFilters() {
    setState(() {
      payerFilterUid = null;
      participantFilterUid = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();

    return AppScaffold(
      title: 'Transaction History',
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(widget.groupId),
        builder: (context, memSnap) {
          if (!memSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = memSnap.data!;
          final memberMap = <String, GroupMember>{
            for (final m in members) m.id: m,
          };

          return StreamBuilder<List<GroupTx>>(
            stream: repo.watchTx(widget.groupId),
            builder: (context, txSnap) {
              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allTxs = txSnap.data!
                  .where((t) => t.status == TxStatus.approved)
                  .toList()
                ..sort((a, b) => b.at.compareTo(a.at));

              // ✅ apply filters
              final filtered = allTxs.where((tx) {
                final passPayer = payerFilterUid == null
                    ? true
                    : tx.payers.any((p) => p.uid == payerFilterUid);

                final passParticipant = participantFilterUid == null
                    ? true
                    : tx.participants.contains(participantFilterUid);

                return passPayer && passParticipant;
              }).toList();

              return Column(
                children: [
                  _FilterBar(
                    members: members,
                    memberMap: memberMap,
                    payerUid: payerFilterUid,
                    participantUid: participantFilterUid,
                    onPayerChanged: (uid) => setState(() => payerFilterUid = uid),
                    onParticipantChanged: (uid) =>
                        setState(() => participantFilterUid = uid),
                    onClear: _clearFilters,
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyFilteredState(
                      hasAnyTx: allTxs.isNotEmpty,
                      onClear: _clearFilters,
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _activityTile(
                        context,
                        filtered[i],
                        groupId: widget.groupId,
                        memberMap: memberMap,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ✅ SAME UI CARD
  Widget _activityTile(
      BuildContext context,
      GroupTx tx, {
        required String groupId,
        required Map<String, GroupMember> memberMap,
      }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final title = (tx.category == null || tx.category!.trim().isEmpty)
        ? (tx.type == 'settlement' ? 'Settlement' : 'Expense')
        : tx.category!.trim();

    final total = tx.amount;
    final participantsCount = tx.participants.length;
    final dateText = Fmt.date(tx.at);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/group/$groupId/tx/${tx.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE + TOTAL
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  Fmt.money(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // PAYERS
            if (tx.payers.isNotEmpty) ...[
              Text(
                'Paid by',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              ...tx.payers.map((payer) {
                final payerName = memberMap[payer.uid]?.name ?? 'Unknown';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          payerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        Fmt.money(payer.amount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              Text(
                'Paid by: —',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // PARTICIPANTS + DATE
            Row(
              children: [
                Text(
                  '$participantsCount participant${participantsCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '• $dateText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================= FILTER UI =================

class _FilterBar extends StatelessWidget {
  final List<GroupMember> members;
  final Map<String, GroupMember> memberMap;

  final String? payerUid;
  final String? participantUid;

  final ValueChanged<String?> onPayerChanged;
  final ValueChanged<String?> onParticipantChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.members,
    required this.memberMap,
    required this.payerUid,
    required this.participantUid,
    required this.onPayerChanged,
    required this.onParticipantChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasAnyFilter = payerUid != null || participantUid != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DropdownFilter(
              label: 'Payer',
              valueUid: payerUid,
              members: members,
              memberMap: memberMap,
              onChanged: onPayerChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DropdownFilter(
              label: 'Participant',
              valueUid: participantUid,
              members: members,
              memberMap: memberMap,
              onChanged: onParticipantChanged,
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Clear filters',
            onPressed: hasAnyFilter ? onClear : null,
            icon: Icon(
              Icons.close_rounded,
              color: hasAnyFilter
                  ? cs.onSurfaceVariant
                  : cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String? valueUid;
  final List<GroupMember> members;
  final Map<String, GroupMember> memberMap;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.label,
    required this.valueUid,
    required this.members,
    required this.memberMap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final selectedName =
    valueUid == null ? 'All' : (memberMap[valueUid!]?.name ?? 'Unknown');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showModalBottomSheet<String?>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: cs.surface,
          builder: (ctx) {
            final items = [...members]
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text('All $label'),
                    trailing:
                    valueUid == null ? const Icon(Icons.check_rounded) : null,
                    onTap: () => Navigator.pop(ctx, null),
                  ),
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ...items.map((m) {
                    final isSelected = valueUid == m.id;
                    return ListTile(
                      title: Text(m.name),
                      trailing: isSelected ? const Icon(Icons.check_rounded) : null,
                      onTap: () => Navigator.pop(ctx, m.id),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );

        // picked can be null (All) or uid
        onChanged(picked);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label: $selectedName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilteredState extends StatelessWidget {
  final bool hasAnyTx;
  final VoidCallback onClear;

  const _EmptyFilteredState({
    required this.hasAnyTx,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!hasAnyTx) {
      return const Center(child: Text('No transactions yet'));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No transactions match your filters.',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onClear,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}