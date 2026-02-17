import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';

class GroupCombinedScreen extends StatelessWidget {
  final String groupId;
  const GroupCombinedScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = AppColors.bg(isDark);
    final card = AppColors.card(isDark);
    final stroke = AppColors.stroke(isDark);
    final text = AppColors.text(isDark);
    final subText = AppColors.subText(isDark);

    return AppScaffold(
      title: 'Combined Summary',
      backgroundColor: bg,
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(groupId),
        builder: (context, memSnap) {
          if (!memSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = memSnap.data!;
          final nameByUid = <String, String>{
            for (final m in members) m.id: m.name,
          };

          return StreamBuilder<List<GroupTx>>(
            stream: repo.watchTx(groupId),
            builder: (context, txSnap) {
              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final txs = txSnap.data!
                  .where((t) => t.status == TxStatus.approved)
                  .toList();

              // ================= TOTAL GROUP EXPENSE =================
              final totalExpense = txs
                  .where((t) => t.type == 'expense')
                  .fold<double>(0.0, (sum, t) => sum + t.amount);

              // ================= CATEGORY TOTAL =================
              final categoryTotals = <String, double>{};
              for (final tx in txs.where((t) => t.type == 'expense')) {
                final cat = (tx.category == null || tx.category!.trim().isEmpty)
                    ? 'Uncategorized'
                    : tx.category!.trim();
                categoryTotals[cat] = (categoryTotals[cat] ?? 0) + tx.amount;
              }

              // ================= MEMBER TOTALS =================
              final memberExpense = <String, double>{};
              final memberPaid = <String, double>{};

              for (final tx in txs.where((t) => t.type == 'expense')) {
                // Who paid
                for (final payer in tx.payers) {
                  memberPaid[payer.uid] = (memberPaid[payer.uid] ?? 0) + payer.amount;
                }

                // Who participated
                final participants = tx.participants;
                if (participants.isNotEmpty) {
                  final share = tx.amount / participants.length;
                  for (final uid in participants) {
                    memberExpense[uid] = (memberExpense[uid] ?? 0) + share;
                  }
                }
              }

              List<MapEntry<String, double>> _sorted(Map<String, double> m) {
                final list = m.entries.toList();
                list.sort((a, b) => b.value.compareTo(a.value));
                return list;
              }

              String _nameOf(String uid) => nameByUid[uid] ?? 'Unknown member';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== TOTAL =====
                    _CardBlock(
                      bg: card,
                      stroke: stroke,
                      child: Column(
                        children: [
                          Text(
                            'Total Group Expense',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Fmt.money(totalExpense),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppColors.green,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== CATEGORY =====
                    Text(
                      'By Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _CardBlock(
                      bg: card,
                      stroke: stroke,
                      child: Column(
                        children: _sorted(categoryTotals).map((e) {
                          return _RowItem(
                            title: e.key,
                            value: Fmt.money(e.value),
                            text: text,
                            subText: subText,
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== MEMBER EXPENSE =====
                    Text(
                      'Expense per Member',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _CardBlock(
                      bg: card,
                      stroke: stroke,
                      child: Column(
                        children: _sorted(memberExpense).map((e) {
                          return _RowItem(
                            title: _nameOf(e.key), // ✅ NAME instead of UID
                            value: Fmt.money(e.value),
                            text: text,
                            subText: subText,
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== MEMBER PAID =====
                    Text(
                      'Paid by Members',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _CardBlock(
                      bg: card,
                      stroke: stroke,
                      child: Column(
                        children: _sorted(memberPaid).map((e) {
                          return _RowItem(
                            title: _nameOf(e.key), // ✅ NAME instead of UID
                            value: Fmt.money(e.value),
                            text: text,
                            subText: subText,
                          );
                        }).toList(),
                      ),
                    ),
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

class _CardBlock extends StatelessWidget {
  final Color bg;
  final Color stroke;
  final Widget child;

  const _CardBlock({
    required this.bg,
    required this.stroke,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
      ),
      child: child,
    );
  }
}

class _RowItem extends StatelessWidget {
  final String title;
  final String value;
  final Color text;
  final Color subText;

  const _RowItem({
    required this.title,
    required this.value,
    required this.text,
    required this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: text, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}