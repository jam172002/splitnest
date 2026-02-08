import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../widgets/app_scaffold.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  // Brand accent (OK to keep constant)
  static const Color kBrandGreen = Color(0xFF20C84A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final auth = context.watch<AuthRepo>();
    final uid = auth.currentUser?.uid ?? '';

    // Theme-responsive surfaces
    final bgTop = isDark ? cs.surface : cs.surface;
    final bgBottom = isDark ? cs.surface : cs.surface;
    final cardColor = isDark ? cs.surfaceContainerLowest : cs.surface;
    final cardBorder = cs.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.35);

    // Text colors responsive
    final titleColor = cs.onSurface;
    final subText = cs.onSurfaceVariant.withValues(alpha: isDark ? 0.85 : 0.9);

    return AppScaffold(
      title: 'Groups',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: PopupMenuButton<_GroupsMenu>(
            tooltip: 'More',
            color: cs.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurface.withValues(alpha: 0.75)),
            onSelected: (v) {
              switch (v) {
                case _GroupsMenu.join:
                  context.push('/join-group');
                  break;
                case _GroupsMenu.create:
                  context.push('/create-group');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _GroupsMenu.join,
                child: Row(
                  children: [
                    const Icon(Icons.group_add_outlined, size: 18, color: kBrandGreen),
                    const SizedBox(width: 10),
                    Text('Join group', style: TextStyle(color: cs.onSurface)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _GroupsMenu.create,
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 18, color: kBrandGreen),
                    const SizedBox(width: 10),
                    Text('Create group', style: TextStyle(color: cs.onSurface)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bgTop,
              bgBottom,
            ],
          ),
        ),
        child: StreamBuilder<List<Group>>(
          stream: context.read<GroupRepo>().watchMyGroups(uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final items = snap.data ?? [];

            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 1),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: cardBorder),
                        ),
                        child: const Icon(Icons.groups_rounded, size: 38, color: kBrandGreen),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No groups yet',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a group or join one from the menu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subText,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => context.push('/create-group'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create group'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kBrandGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final g = items[i];
                final membersCount = g.memberUids.length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.push('/group/${g.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // smaller avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    kBrandGreen,
                                    kBrandGreen.withValues(alpha: 0.75),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: kBrandGreen.withValues(alpha: isDark ? 0.18 : 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    g.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: titleColor,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      fontSize: 15, // smaller than before
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.30 : 0.55),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_alt_rounded, size: 14, color: kBrandGreen),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$membersCount member${membersCount == 1 ? '' : 's'}',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12, // smaller
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),
                            Icon(Icons.chevron_right_rounded, size: 18, color: cs.outline.withValues(alpha: 0.8)),
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

enum _GroupsMenu { join, create }