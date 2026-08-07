import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/personal_repo.dart';
import '../../../domain/models/personal_tx.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/period_selector.dart';

class PersonalAnalyticsScreen extends StatefulWidget {
  const PersonalAnalyticsScreen({super.key});

  @override
  State<PersonalAnalyticsScreen> createState() => _PersonalAnalyticsScreenState();
}

class _PersonalAnalyticsScreenState extends State<PersonalAnalyticsScreen> {
  DateRange? _range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Analytics',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PeriodSelector(
                initial: PeriodType.month,
                onChanged: (r) => setState(() => _range = r),
              ),
            ),
          ),
          Expanded(
            child: _range == null
                ? const SizedBox.shrink()
                : StreamBuilder<List<PersonalTx>>(
                    stream: context.read<PersonalRepo>().watchPersonal(uid),
                    builder: (context, snap) {
                      final all = snap.data ?? const <PersonalTx>[];
                      final range = _range!;
                      final inRange = all
                          .where((t) => range.contains(t.at))
                          .where((t) => t.type == PersonalTxType.expense || t.type == PersonalTxType.income)
                          .toList();

                      if (inRange.isEmpty) {
                        return const EmptyHint('No income or expenses in this period.');
                      }

                      double totalIncome = 0;
                      double totalExpense = 0;
                      final Map<String, double> expenseByCategory = {};

                      for (final t in inRange) {
                        if (t.type == PersonalTxType.income) {
                          totalIncome += t.amount;
                        } else {
                          totalExpense += t.amount;
                          final cat = t.categoryOrDefault;
                          expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + t.amount;
                        }
                      }

                      final sortedCategories = expenseByCategory.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    label: 'Income',
                                    value: Fmt.money(totalIncome),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    label: 'Expenses',
                                    value: Fmt.money(totalExpense),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Income vs Expense',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: _IncomeExpenseBarChart(
                                income: totalIncome,
                                expense: totalExpense,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Expenses by Category',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 12),
                            if (sortedCategories.isEmpty)
                              Text(
                                'No expenses in this period.',
                                style: theme.textTheme.bodyMedium,
                              )
                            else
                              _CategoryPie(entries: sortedCategories, isDark: isDark),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _StatCard({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke(isDark)),
        color: AppColors.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.subText(isDark))),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.text(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseBarChart extends StatelessWidget {
  final double income;
  final double expense;
  final bool isDark;

  const _IncomeExpenseBarChart({required this.income, required this.expense, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final maxY = [income, expense, 1.0].reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChart(
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
              getTitlesWidget: (value, meta) {
                final label = value == 0 ? 'Income' : 'Expenses';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.subText(isDark),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: income, color: AppColors.green, width: 40, borderRadius: BorderRadius.circular(8)),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(
              toY: expense,
              color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.55),
              width: 40,
              borderRadius: BorderRadius.circular(8),
            ),
          ]),
        ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: colors[i],
                    title: '',
                    radius: 34,
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
    );
  }
}
