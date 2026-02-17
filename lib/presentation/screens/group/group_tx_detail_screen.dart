import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';

class GroupTxDetailScreen extends StatelessWidget {
  final String groupId;
  final String txId;

  const GroupTxDetailScreen({
    super.key,
    required this.groupId,
    required this.txId,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      title: 'Transaction Details',
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded),
        onPressed: () => context.pop(),
      ),
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(groupId),
        builder: (context, memSnap) {
          if (!memSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = memSnap.data!;
          final memberMap = {for (final m in members) m.id: m};

          String nameOf(String uid) {
            if (uid.trim().isEmpty) return '—';
            return memberMap[uid]?.name ?? 'Unknown';
          }

          return StreamBuilder<List<GroupTx>>(
            stream: repo.watchTx(groupId),
            builder: (context, txSnap) {
              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              GroupTx? tx;
              for (final t in txSnap.data!) {
                if (t.id == txId) {
                  tx = t;
                  break;
                }
              }

              if (tx == null) {
                return const Center(child: Text('Transaction not found.'));
              }

              final isExpense = tx.type == 'expense' || tx.type == 'bill_instance';
              final isIncome = tx.type == 'income';
              final isSettlement = tx.type == 'settlement';

              // --- Payers (multi-payer) ---
              final payers = tx.payers;
              final totalPaid = payers.fold<double>(0, (s, p) => s + p.amount);

              // --- Participants split ---
              // You do not store per-user shares for expense in this model,
              // so we show "equal split" for participants (common behavior).
              final participants = tx.participants;
              final participantShare = (participants.isNotEmpty)
                  ? tx.amount / participants.length
                  : 0.0;

              // --- Income distribution map ---
              final dist = tx.distributeTo; // uid -> amount
              final distTotal = dist.values.fold<double>(0, (s, v) => s + v);

              // endorsedBy & createdBy names
              final endorsedNames = tx.endorsedBy.map(nameOf).toList();
              final createdByName = nameOf(tx.createdBy);

              // settlement names
              final fromName = nameOf(tx.fromUid ?? '');
              final toName = nameOf(tx.toUid ?? '');

              IconData iconForType() {
                if (isSettlement) return Icons.handshake_outlined;
                if (isIncome) return Icons.trending_up_rounded;
                return Icons.receipt_long_outlined;
              }

              Color iconBg() {
                if (isSettlement) return cs.tertiaryContainer.withValues(alpha: 0.45);
                if (isIncome) return cs.secondaryContainer.withValues(alpha: 0.45);
                return cs.primaryContainer.withValues(alpha: 0.45);
              }

              Color iconFg() {
                if (isSettlement) return cs.tertiary;
                if (isIncome) return cs.secondary;
                return cs.primary;
              }

              String titleForType() {
                if (isSettlement) return 'Settlement';
                if (isIncome) return 'Income';
                if (tx?.type == 'bill_instance') return 'Bill';
                return 'Expense';
              }

              Widget sectionTitle(String t) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 10),
                child: Text(
                  t,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              );

              Widget infoRow(String label, String value) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 115,
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              Widget card({required Widget child}) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                ),
                child: child,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: iconBg(),
                                child: Icon(iconForType(), color: iconFg()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  titleForType(),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                Fmt.money(tx.amount),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            Fmt.date(tx.at),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((tx.category ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              tx.category!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          if ((tx.description ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              tx.description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    sectionTitle('Basics'),
                    card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoRow('Type', tx.type),
                          infoRow('Status', tx.status.name),
                          infoRow('Created by', createdByName),
                          if (tx.endorsedBy.isNotEmpty)
                            infoRow('Endorsed by', endorsedNames.join(', ')),
                        ],
                      ),
                    ),

                    // Settlement block
                    if (isSettlement) ...[
                      sectionTitle('Settlement'),
                      card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            infoRow('From', fromName),
                            infoRow('To', toName),
                            infoRow('Amount', Fmt.money(tx.amount)),
                          ],
                        ),
                      ),
                    ],

                    // Payers block (expense/income/bill)
                    if (!isSettlement) ...[
                      sectionTitle('Payer(s)'),
                      card(
                        child: payers.isEmpty
                            ? Text(
                          'No payer info found.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                            : Column(
                          children: [
                            ...payers.map((p) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  nameOf(p.uid),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                trailing: Text(
                                  Fmt.money(p.amount),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            }),
                            Divider(color: cs.outlineVariant.withValues(alpha: 0.25)),
                            Row(
                              children: [
                                Text(
                                  'Total paid',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  Fmt.money(totalPaid),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Participants (expense/bill split)
                    if (isExpense) ...[
                      sectionTitle('Participants'),
                      card(
                        child: participants.isEmpty
                            ? Text(
                          'No participants saved.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                            : Column(
                          children: [
                            ...participants.map((uid) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  nameOf(uid),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                trailing: Text(
                                  Fmt.money(participantShare),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            }),
                            Divider(color: cs.outlineVariant.withValues(alpha: 0.25)),
                            Row(
                              children: [
                                Text(
                                  'Split',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  participants.isEmpty
                                      ? '—'
                                      : 'Equal (${participants.length} people)',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Income distribution (business income)
                    if (isIncome) ...[
                      sectionTitle('Distributed to'),
                      card(
                        child: dist.isEmpty
                            ? Text(
                          'No distribution data saved.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                            : Column(
                          children: [
                            ...dist.entries.map((e) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  nameOf(e.key),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                trailing: Text(
                                  Fmt.money(e.value),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            }),
                            Divider(color: cs.outlineVariant.withValues(alpha: 0.25)),
                            Row(
                              children: [
                                Text(
                                  'Total distributed',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  Fmt.money(distTotal),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}