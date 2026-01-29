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
      // Keeping your original actions – only minor spacing polish
      actions: [
        IconButton(
          onPressed: () => context.push('/join-group'),
          icon: Icon(Icons.group_add_outlined, color: colorScheme.primary),
          tooltip: 'Join group',
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton.filledTonal(
            onPressed: () => context.push('/create-group'),
            icon: const Icon(Icons.add),
            tooltip: 'Create group',
          ),
        ),
      ],
      child: Container(
        // Soft gradient background – Telegram-like feel
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.08),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: StreamBuilder<List<Group>>(
          stream: context.read<GroupRepo>().watchMyGroups(uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snap.data ?? [];

            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large subtle icon
                    Icon(
                      Icons.group_outlined,
                      size: 96,
                      color: colorScheme.primary.withOpacity(0.38),
                    ),
                    const SizedBox(height: 40),

                    Text(
                      'Groups',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'No groups yet.',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Tap the + button to get started.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.85),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Prominent pill-shaped button
                    FilledButton.icon(
                      onPressed: () => context.push('/create-group'),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Add Group',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 16,
                        ),
                        shape: const StadiumBorder(),
                        elevation: 1,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final g = items[i];
                final membersCount = g.memberUids.length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => context.push('/group/${g.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Slightly larger & more modern avatar
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primaryContainer,
                                    colorScheme.primaryContainer.withOpacity(0.65),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer
                                          .withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.people_alt_rounded,
                                          size: 15,
                                          color: colorScheme.onSecondaryContainer
                                              .withOpacity(0.9),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$membersCount member${membersCount == 1 ? '' : 's'}',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                            color: colorScheme
                                                .onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: colorScheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}