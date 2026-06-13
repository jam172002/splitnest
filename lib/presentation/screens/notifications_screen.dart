import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/auth_repo.dart';
import '../../data/group_repo.dart';
import '../../data/notifications_repo.dart';
import '../../domain/models/group_notification.dart';
import '../../domain/models/tx.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_hint.dart';

class NotificationsScreen extends StatefulWidget {
  final String? groupId;

  const NotificationsScreen({super.key, this.groupId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _busyNotifications = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupId = widget.groupId;
      if (!mounted || groupId == null) return;
      final uid = context.read<AuthRepo>().currentUser!.uid;
      context.read<NotificationsRepo>().markGroupAsRead(uid, groupId);
    });
  }

  Future<void> _respond(
    GroupNotification notification, {
    required bool approve,
  }) async {
    setState(() => _busyNotifications.add(notification.id));
    final uid = context.read<AuthRepo>().currentUser!.uid;
    final groupRepo = context.read<GroupRepo>();
    final notificationsRepo = context.read<NotificationsRepo>();

    try {
      final group = await groupRepo.getGroup(notification.groupId);
      final isAdmin =
          await groupRepo.roleOf(notification.groupId, uid) == 'admin';
      final tx = await groupRepo.getTx(notification.groupId, notification.txId);
      if (tx == null || tx.status != TxStatus.pending) {
        throw Exception('This expense has already been handled');
      }

      if (approve) {
        await groupRepo.endorseExpense(
          groupId: notification.groupId,
          txId: notification.txId,
          uid: uid,
          group: group,
          isAdmin: isAdmin,
        );
      } else {
        await groupRepo.rejectExpense(
          groupId: notification.groupId,
          txId: notification.txId,
          uid: uid,
          isAdmin: isAdmin,
        );
      }
      await notificationsRepo.markAsRead(uid, notification.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyNotifications.remove(notification.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthRepo>().currentUser!.uid;
    final repo = context.read<NotificationsRepo>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppScaffold(
      title: widget.groupId == null ? 'Notifications' : 'Group Notifications',
      child: StreamBuilder<List<GroupNotification>>(
        stream: repo.watchNotifications(uid, groupId: widget.groupId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const EmptyHint('No notifications yet.');
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final item = notifications[index];
              final busy = _busyNotifications.contains(item.id);
              return Card(
                elevation: 0,
                color: item.isRead
                    ? colors.surfaceContainerLow
                    : colors.primaryContainer.withValues(alpha: 0.35),
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await repo.markAsRead(uid, item.id);
                    if (context.mounted && item.txId.isNotEmpty) {
                      context.push('/group/${item.groupId}/tx/${item.txId}');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              Fmt.money(item.amount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: item.type == 'expense_disputed'
                                    ? colors.error
                                    : colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (widget.groupId == null)
                          Text(
                            item.groupName,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        Text(
                          item.category,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.note),
                        ],
                        if (item.message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (item.requiresAction) ...[
                          const SizedBox(height: 12),
                          FutureBuilder<GroupTx?>(
                            future: context
                                .read<GroupRepo>()
                                .getTx(item.groupId, item.txId),
                            builder: (context, txSnapshot) {
                              final isPending =
                                  txSnapshot.data?.status == TxStatus.pending;
                              if (!isPending) {
                                return Text(
                                  'This request has been handled.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                );
                              }
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => _respond(item, approve: false),
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.error,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonal(
                                    onPressed: busy
                                        ? null
                                        : () => _respond(item, approve: true),
                                    child:
                                        Text(busy ? 'Please wait...' : 'Okay'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
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
}
