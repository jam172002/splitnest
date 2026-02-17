import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';

class GroupTransactionHistoryScreen extends StatelessWidget {
  final String groupId;

  const GroupTransactionHistoryScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();

    return AppScaffold(
      title: 'Transaction History',
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(groupId),
        builder: (context, memSnap) {
          if (!memSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = memSnap.data!;
          final memberMap = <String, GroupMember>{
            for (final m in members) m.id: m,
          };

          return StreamBuilder<List<GroupTx>>(
            stream: repo.watchTx(groupId),
            builder: (context, txSnap) {
              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final txs = txSnap.data!
              // keep same behavior as dashboard: approved only
                  .where((t) => t.status == TxStatus.approved)
                  .toList()
                ..sort((a, b) => b.at.compareTo(a.at));

              if (txs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No transactions yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: txs.length,
                itemBuilder: (context, i) => _activityTile(
                  context,
                  txs[i],
                  groupId: groupId,
                  memberMap: memberMap,
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ✅ SAME UI AS YOUR DASHBOARD TILE (copy-compatible)
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
            // ================= TITLE + TOTAL =================
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

            // ================= PAYERS MULTI ROW =================
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
              // Optional fallback if no payers stored
              Text(
                'Paid by: —',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ================= PARTICIPANTS + DATE =================
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