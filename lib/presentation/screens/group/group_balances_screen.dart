import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/member_balance.dart';
import '../../widgets/app_scaffold.dart';
import 'member_transaction_detail_screen.dart';

class GroupBalancesScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupBalancesScreen({
    super.key,
    required this.groupId,
    this.groupName = 'Group Balances',
  });

  @override
  Widget build(BuildContext context) {
    // Switching to context.read for better architecture consistency
    final groupRepo = context.read<GroupRepo>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: groupName,
      child: FutureBuilder<List<MemberBalance>>(
        future: groupRepo.getMemberBalances(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading balances:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            );
          }

          final balances = snapshot.data ?? [];

          if (balances.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_outlined, size: 64, color: colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  const Text('No transactions yet.', textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: balances.length,
            itemBuilder: (context, index) {
              final balance = balances[index];
              final isPositive = balance.netBalance > 0;
              final isNegative = balance.netBalance < 0;

              // Using theme-aware colors for financial indicators
              final statusColor = isPositive
                  ? Colors.green
                  : (isNegative ? colorScheme.error : colorScheme.outline);

              final icon = isPositive
                  ? Icons.arrow_upward_rounded
                  : (isNegative ? Icons.arrow_downward_rounded : Icons.remove_rounded);

              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow, // Matches your theme
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: statusColor.withOpacity(0.1),
                        child: Text(
                          balance.name.isNotEmpty ? balance.name[0].toUpperCase() : '?',
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: statusColor,
                        child: Icon(icon, size: 10, color: Colors.white),
                      ),
                    ],
                  ),
                  title: Text(
                    balance.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    balance.balanceDisplay,
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isPositive ? "+" : ""}${balance.netBalance.toStringAsFixed(0)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: colorScheme.outlineVariant),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MemberTransactionDetailScreen(
                          groupId: groupId,
                          member: GroupMember(
                            id: balance.memberId,
                            name: balance.name,
                            role: 'member',
                            joinedAt: DateTime.now(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}