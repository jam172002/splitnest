import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/period_selector.dart';

class GroupCombinedScreen extends StatefulWidget {
  final String groupId;
  const GroupCombinedScreen({super.key, required this.groupId});

  @override
  State<GroupCombinedScreen> createState() => _GroupCombinedScreenState();
}

class _GroupCombinedScreenState extends State<GroupCombinedScreen> {
  DateRange? _range;

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
        stream: repo.watchMembers(widget.groupId),
        builder: (context, memSnap) {
          if (!memSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = memSnap.data!;
          final nameByUid = <String, String>{
            for (final m in members) m.id: m.name,
          };

          return StreamBuilder<List<GroupTx>>(
            stream: repo.watchTx(widget.groupId),
            builder: (context, txSnap) {
              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final range = _range;
              final txs = txSnap.data!
                  .where((t) => t.status == TxStatus.approved)
                  .where((t) => range == null ? true : range.contains(t.at))
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
                  if (tx.participantShares.isNotEmpty) {
                    for (final uid in participants) {
                      final share = tx.participantShares[uid] ?? 0.0;
                      memberExpense[uid] = (memberExpense[uid] ?? 0) + share;
                    }
                  } else {
                    final share = tx.amount / participants.length;
                    for (final uid in participants) {
                      memberExpense[uid] = (memberExpense[uid] ?? 0) + share;
                    }
                  }
                }
              }

              List<MapEntry<String, double>> sortedEntries(Map<String, double> m) {
                final list = m.entries.toList();
                list.sort((a, b) => b.value.compareTo(a.value));
                return list;
              }

              String nameOf(String uid) => nameByUid[uid] ?? 'Unknown member';

              final sortedCategories = sortedEntries(categoryTotals);
              final sortedMemberExpense = sortedEntries(memberExpense);
              final sortedMemberPaid = sortedEntries(memberPaid);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PeriodSelector(
                      initial: PeriodType.month,
                      onChanged: (r) => setState(() => _range = r),
                    ),
                    const SizedBox(height: 16),

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

                    if (sortedCategories.isNotEmpty) ...[
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
                        child: _CategoryPie(entries: sortedCategories, isDark: isDark),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (sortedMemberExpense.isNotEmpty) ...[
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
                        child: _MemberBarChart(
                          entries: sortedMemberExpense,
                          nameOf: nameOf,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CardBlock(
                        bg: card,
                        stroke: stroke,
                        child: Column(
                          children: sortedMemberExpense.map((e) {
                            return _RowItem(
                              title: nameOf(e.key),
                              value: Fmt.money(e.value),
                              text: text,
                              subText: subText,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (sortedMemberPaid.isNotEmpty) ...[
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
                          children: sortedMemberPaid.map((e) {
                            return _RowItem(
                              title: nameOf(e.key),
                              value: Fmt.money(e.value),
                              text: text,
                              subText: subText,
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    if (txs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                            'No approved expenses in this period.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: subText),
                          ),
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

class _CategoryPie extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final bool isDark;

  const _CategoryPie({required this.entries, required this.isDark});

  static List<Color> _palette(bool isDark, int count) {
    final base = AppColors.green;
    final anchors = isDark ? Colors.white : Colors.black;
    return List.generate(count, (i) {
      final t = count <= 1 ? 0.0 : (i / (count - 1)) * 0.55;
      return Color.lerp(base, anchors, t)!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final colors = _palette(isDark, entries.length);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: colors[i],
                      title: '',
                      radius: 30,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entries[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.text(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          total <= 0 ? '0%' : '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.subText(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberBarChart extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final String Function(String uid) nameOf;
  final bool isDark;

  const _MemberBarChart({required this.entries, required this.nameOf, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final top = entries.take(6).toList();
    final maxY = top.isEmpty ? 1.0 : top.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= top.length) return const SizedBox.shrink();
                  final name = nameOf(top[i].key);
                  final shortName = name.length > 8 ? '${name.substring(0, 7)}…' : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      shortName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.subText(isDark)),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < top.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: top[i].value,
                  color: AppColors.green,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ]),
          ],
        ),
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
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
