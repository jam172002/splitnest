import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';

class MembersScreen extends StatelessWidget {
  final String groupId;
  const MembersScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Members',
      child: StreamBuilder<List<GroupMember>>(
        stream: context.read<GroupRepo>().watchMembers(groupId),
        builder: (context, snap) {
          final items = snap.data ?? [];
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = items[i];
              return ListTile(
                title: Text(m.email),
                subtitle: Text(m.role),
              );
            },
          );
        },
      ),
    );
  }
}
