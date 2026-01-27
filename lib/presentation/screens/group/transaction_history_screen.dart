import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/format.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';

class GroupTransactionHistoryScreen extends StatelessWidget {
  final String groupId;

  const GroupTransactionHistoryScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();

    return AppScaffold(
      title: 'Transaction History',
      child: StreamBuilder<List<GroupTx>>(
        stream: repo.watchTx(groupId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final txs = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: txs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final tx = txs[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  child: Icon(tx.type == 'settlement' ? Icons.handshake : Icons.receipt_long),
                ),
                title: Text(tx.category ?? (tx.type == 'settlement' ? 'Settlement' : 'Expense')),
                subtitle: Text(Fmt.date(tx.at)),
                trailing: Text(
                  Fmt.money(tx.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}