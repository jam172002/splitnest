import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/chat_repo.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthRepo>().currentUser!.uid;
    final repo = context.read<ChatRepo>();

    return FutureBuilder<String>(
      future: repo.ensurePublicId(uid),
      builder: (context, idSnapshot) => AppScaffold(
        title: 'Chat',
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repo.watchIncomingRequests(uid),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: IconButton(
                  tooltip: 'Friend requests',
                  onPressed: () => _showRequests(context, repo, uid),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Add friend by ID',
            onPressed: () => _showAddFriend(context, repo, uid),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repo.watchFriends(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final friends = snapshot.data!.docs;
            if (friends.isEmpty) {
              return const EmptyHint(
                'No conversations yet.\nAdd a friend using their 10-digit ID.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: friends.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final friendUid = friends[index].id;
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: repo.watchUser(friendUid),
                  builder: (context, userSnapshot) {
                    final data = userSnapshot.data?.data();
                    final name = data?['name'] as String? ?? 'User';
                    final publicId = data?['publicId'] as String? ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle:
                          Text(publicId.isEmpty ? 'Connected' : 'ID $publicId'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/chat/$friendUid'),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Future<void> _showAddFriend(
    BuildContext context,
    ChatRepo repo,
    String uid,
  ) async {
    final controller = TextEditingController();
    String? error;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the user\'s 10-digit SplitNest ID.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'User ID',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final publicId = controller.text.trim();
                      if (!RegExp(r'^\d{10}$').hasMatch(publicId)) {
                        setState(() => error = 'Enter a valid 10-digit ID');
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final user = await repo.findUserByPublicId(publicId);
                        if (user == null) throw Exception('User not found');
                        await repo.sendFriendRequest(
                          fromUid: uid,
                          toUid: user.id,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Friend request sent')),
                          );
                        }
                      } catch (exception) {
                        setState(() {
                          busy = false;
                          error = exception
                              .toString()
                              .replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: Text(busy ? 'Sending...' : 'Send request'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  static Future<void> _showRequests(
    BuildContext context,
    ChatRepo repo,
    String uid,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.watchIncomingRequests(uid),
        builder: (context, snapshot) {
          final requests = snapshot.data?.docs ?? [];
          if (requests.isEmpty) {
            return const SizedBox(
              height: 180,
              child: Center(child: Text('No pending friend requests')),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return ListTile(
                title: Text(request.data()['fromName'] ?? 'User'),
                subtitle: const Text('Wants to connect with you'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Reject',
                      onPressed: () => repo.respondToRequest(
                        requestId: request.id,
                        currentUid: uid,
                        accept: false,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Accept',
                      onPressed: () => repo.respondToRequest(
                        requestId: request.id,
                        currentUid: uid,
                        accept: true,
                      ),
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
