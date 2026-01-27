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

          // Sort: Admins first, then by join date
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
                  trailing: Container(
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context, GroupRepo repo) {
    final nameController = TextEditingController();
    String role = 'member';
    bool isBusy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
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
                      if (nameController.text.trim().isEmpty) return;
                      setModalState(() => isBusy = true);
                      try {
                        await repo.addMember(
                          groupId: groupId,
                          name: nameController.text.trim(),
                          role: role,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } finally {
                        setModalState(() => isBusy = false);
                      }
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