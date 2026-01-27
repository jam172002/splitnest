import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthRepo>();
    final uid = auth.currentUser?.uid ?? '';

    return AppScaffold(
      title: 'Groups',
      // Clean, modern AppBar actions
      actions: [
        IconButton(
          onPressed: () => context.push('/app/groups/join'),
          icon: Icon(Icons.group_add_outlined, color: colorScheme.primary),
          tooltip: 'Join group',
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: IconButton.filledTonal(
            onPressed: () => context.push('/app/groups/create'),
            icon: const Icon(Icons.add),
            tooltip: 'Create group',
          ),
        ),
      ],
      child: StreamBuilder<List<Group>>(
        stream: context.read<GroupRepo>().watchMyGroups(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? [];

          if (items.isEmpty) {
            return const EmptyHint(
              'No groups yet.\nTap the + button to get started.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final g = items[i];
              final membersCount = g.membersCount;

              // Use standard Card but let the theme handle the shape/elevation
              return Card(
                // We use surfaceContainerLow to give a subtle contrast against the background
                color: colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12), // M3 uses squarer radii
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    g.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 14,
                            color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '$membersCount member${membersCount == 1 ? '' : 's'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colorScheme.outlineVariant,
                  ),
                  onTap: () => context.push('/group/${g.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}