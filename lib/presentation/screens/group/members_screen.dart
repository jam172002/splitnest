import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class MembersScreen extends StatelessWidget {
  final String groupId;

  const MembersScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Group Members',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemberSheet(context, repo),
        child: const Icon(Icons.person_add_rounded),
      ),
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(groupId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final members = snapshot.data!;
          if (members.isEmpty) return const Center(child: Text('No members found'));

          members.sort((a, b) {
            if (a.role == 'admin' && b.role != 'admin') return -1;
            if (a.role != 'admin' && b.role == 'admin') return 1;
            return a.joinedAt.compareTo(b.joinedAt);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final m = members[index];
              final isAdmin = m.role == 'admin';

              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? colorScheme.primary : colorScheme.secondaryContainer,
                    child: Text(m.initials,
                        style: TextStyle(color: isAdmin ? colorScheme.onPrimary : colorScheme.onSecondaryContainer)),
                  ),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Joined ${m.joinedAt.day}/${m.joinedAt.month}/${m.joinedAt.year}'),
                  // --- Added Delete Button ---
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. The existing Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAdmin ? colorScheme.tertiaryContainer : colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            m.role.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isAdmin ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // 2. The NEW Delete Button (Hidden for Admins for safety)
                        if (!isAdmin)
                          IconButton(
                            icon: Icon(Icons.person_remove_outlined, color: colorScheme.error),
                            onPressed: () => _confirmDelete(context, repo, m.id, m.name),
                          ),
                      ],
                    ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Delete Confirmation Dialog ---
  void _confirmDelete(BuildContext context, GroupRepo repo, String uid, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Are you sure you want to remove $name from the group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await repo.removeMember(groupId, uid);
              if (context.mounted) Navigator.pop(c);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context, GroupRepo repo) {
    final nameController = TextEditingController();
    String role = 'member';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            bool isBusy = false;

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add New Member', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Assign Role', prefixIcon: Icon(Icons.shield_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setModalState(() => role = v!),
                  ),
                  const SizedBox(height: 24),
                  BusyButton(
                    busy: isBusy,
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;

                      setModalState(() => isBusy = true);
                      final virtualUid = DateTime.now().millisecondsSinceEpoch.toString();

                      await repo.addMember(
                        groupId: groupId, // Fixed 'widget' error
                        name: nameController.text,
                        role: role,
                        uid: virtualUid, // Satisfies new required parameter
                      );

                      if (context.mounted) Navigator.pop(context);
                    },
                    text: 'Add to Group',
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}