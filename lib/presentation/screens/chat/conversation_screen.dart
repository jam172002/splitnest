import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/chat_repo.dart';
import '../../widgets/app_scaffold.dart';

enum _ConversationAction { giveLoan, payLoan, settlement }

class ConversationScreen extends StatefulWidget {
  final String otherUid;

  const ConversationScreen({super.key, required this.otherUid});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send(ChatRepo repo, String uid, String chatId) async {
    final text = _message.text;
    _message.clear();
    await repo.sendMessage(chatId: chatId, senderUid: uid, text: text);
  }

  Future<void> _financialMessage(
    ChatRepo repo,
    String uid,
    String chatId,
    _ConversationAction action,
  ) async {
    if (action == _ConversationAction.settlement) {
      final groups = await repo.mutualGroups(uid, widget.otherUid);
      if (!mounted) return;
      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You do not share a group with this user')),
        );
        return;
      }
      context.push(
        '/group/${groups.first.id}/add-settlement'
        '?fromUid=$uid&toUid=${widget.otherUid}',
      );
      return;
    }

    final amountController = TextEditingController();
    final isLoan = action == _ConversationAction.giveLoan;
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLoan ? 'Give loan' : 'Pay loan'),
        content: TextField(
          controller: amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Amount', prefixText: 'PKR '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(amountController.text.trim()),
            ),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null || amount <= 0) return;
    try {
      if (isLoan) {
        await repo.recordLoan(
          chatId: chatId,
          lenderUid: uid,
          borrowerUid: widget.otherUid,
          amount: amount,
        );
      } else {
        await repo.recordLoanPayment(
          chatId: chatId,
          payerUid: uid,
          receiverUid: widget.otherUid,
          amount: amount,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthRepo>().currentUser!.uid;
    final repo = context.read<ChatRepo>();
    final chatId = repo.chatIdFor(uid, widget.otherUid);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.watchUser(widget.otherUid),
      builder: (context, userSnapshot) {
        final name =
            userSnapshot.data?.data()?['name'] as String? ?? 'Conversation';
        return AppScaffold(
          title: name,
          actions: [
            PopupMenuButton<_ConversationAction>(
              onSelected: (action) =>
                  _financialMessage(repo, uid, chatId, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ConversationAction.giveLoan,
                  child: Text('Give loan'),
                ),
                PopupMenuItem(
                  value: _ConversationAction.payLoan,
                  child: Text('Pay loan'),
                ),
                PopupMenuItem(
                  value: _ConversationAction.settlement,
                  child: Text('Make settlement'),
                ),
              ],
            ),
          ],
          useSafeArea: false,
          child: SafeArea(
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: repo.watchLoanTransactions(chatId),
                  builder: (context, snapshot) {
                    final balance = repo.loanBalanceFor(
                      snapshot.data?.docs ?? const [],
                      uid,
                    );
                    if (balance.abs() <= 0.005) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: colors.tertiaryContainer,
                      child: Text(
                        balance > 0
                            ? 'They owe you ${Fmt.money(balance)}'
                            : 'You owe ${Fmt.money(balance.abs())}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: repo.watchMessages(chatId),
                    builder: (context, snapshot) {
                      final messages = snapshot.data?.docs ?? [];
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data = messages[index].data();
                          final mine = data['senderUid'] == uid;
                          final type = data['type'] as String? ?? 'text';
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: type == 'text'
                                    ? (mine
                                        ? colors.primaryContainer
                                        : colors.surfaceContainerHigh)
                                    : colors.tertiaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(data['text'] as String? ?? ''),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    MediaQuery.of(context).viewInsets.bottom + 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                          ),
                          onSubmitted: (_) => _send(repo, uid, chatId),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _send(repo, uid, chatId),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
