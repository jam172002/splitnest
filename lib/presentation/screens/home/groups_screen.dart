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
    final auth = context.watch<AuthRepo>();
    final uid = auth.currentUser!.uid;

    return AppScaffold(
      title: 'My Groups',
      actions: [
        IconButton(
          onPressed: () => context.push('/app/groups/join'),
          icon: const Icon(Icons.link),
          tooltip: 'Join group',
        ),
        IconButton(
          onPressed: () => context.push('/app/groups/create'),
          icon: const Icon(Icons.add),
          tooltip: 'Create group',
        ),
      ],
      child: StreamBuilder<List<Group>>(
        stream: context.read<GroupRepo>().watchMyGroups(uid),
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) return const EmptyHint('No groups yet.\nCreate or Join a group.');
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final g = items[i];
              return ListTile(
                title: Text(g.name),
                subtitle: Text('Invite code: ${g.id}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/group/${g.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
