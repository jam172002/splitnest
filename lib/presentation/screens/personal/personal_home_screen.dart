import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/personal_repo.dart';
import '../../../domain/models/personal_tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

class PersonalHomeScreen extends StatelessWidget {
  const PersonalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Personal Ledger',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/personal/add'),
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
      ),
      child: StreamBuilder<List<PersonalTx>>(
        stream: context.read<PersonalRepo>().watchPersonal(uid),
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) return const EmptyHint('No personal expenses yet.');

          // --- Calculation Logic ---
          final now = DateTime.now();
          DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));

          double dayTotal = 0, weekTotal = 0, monthTotal = 0;
          for (final t in items) {
            if (DateUtils.isSameDay(t.at, now)) dayTotal += t.amount;
            if (t.at.isAfter(weekStart.subtract(const Duration(seconds: 1)))) weekTotal += t.amount;
            if (t.at.year == now.year && t.at.month == now.month) monthTotal += t.amount;
          }

          return CustomScrollView(
            slivers: [
              // --- Header Stats Section ---
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      Text('THIS MONTH', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        Fmt.money(monthTotal),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _miniStat(context, 'Today', Fmt.money(dayTotal))),
                          const SizedBox(width: 12),
                          Expanded(child: _miniStat(context, 'Weekly', Fmt.money(weekTotal))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- List Header ---
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text('Recent Transactions',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),

              // --- Transaction List ---
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final t = items[i];
                      return Card(
                        elevation: 0,
                        color: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4)),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.secondaryContainer,
                            child: Icon(Icons.receipt_long_outlined,
                                size: 20, color: colorScheme.onSecondaryContainer),
                          ),
                          title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(Fmt.date(t.at)),
                          trailing: Text(
                            Fmt.money(t.amount),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}