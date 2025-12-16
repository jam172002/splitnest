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
    final uid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Personal Ledger',
      fab: FloatingActionButton(
        onPressed: () => context.push('/app/personal/add'),
        child: const Icon(Icons.add),
      ),
      child: StreamBuilder<List<PersonalTx>>(
        stream: context.read<PersonalRepo>().watchPersonal(uid),
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) return const EmptyHint('No personal expenses yet.');

          final now = DateTime.now();
          bool sameDay(DateTime a, DateTime b) =>
              a.year == b.year && a.month == b.month && a.day == b.day;
          DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
          bool inWeek(DateTime d) => d.isAfter(weekStart.subtract(const Duration(seconds: 1)));
          bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

          double day = 0, week = 0, month = 0;
          for (final t in items) {
            if (sameDay(t.at, now)) day += t.amount;
            if (inWeek(t.at)) week += t.amount;
            if (sameMonth(t.at, now)) month += t.amount;
          }

          Widget stat(String label, double v) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  Text(Fmt.money(v), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 170, child: stat('Today', day)),
                  SizedBox(width: 170, child: stat('This Week', week)),
                  SizedBox(width: 170, child: stat('This Month', month)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = items[i];
                    return ListTile(
                      title: Text(t.title),
                      subtitle: Text(Fmt.date(t.at)),
                      trailing: Text(Fmt.money(t.amount)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
