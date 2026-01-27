import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'breakfast';
  String? _paidBy;
  final Set<String> _participants = {};

  bool _isBusy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense(Group group, bool isAdmin) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) throw Exception('Enter a valid amount');
      if (_participants.isEmpty) throw Exception('Select at least one participant');
      if (_paidBy == null) throw Exception('Select who paid');

      final authRepo = context.read<AuthRepo>();
      final myId = authRepo.currentUser!.uid;

      await context.read<GroupRepo>().addExpense(
        groupId: widget.groupId,
        group: group,
        amount: amount,
        category: _category,
        paidBy: _paidBy!,
        participants: _participants.toList(),
        description: _descriptionController.text.trim(),
        at: DateTime.now(),
        createdBy: myId,
        isAdmin: isAdmin,
      );

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repo = context.read<GroupRepo>();
    final authRepo = context.read<AuthRepo>();
    final myId = authRepo.currentUser!.uid;

    return StreamBuilder<Group>(
      stream: repo.watchGroup(widget.groupId),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final group = groupSnapshot.data!;

        return FutureBuilder<String>(
          future: repo.roleOf(widget.groupId, myId),
          builder: (context, roleSnapshot) {
            final isAdmin = roleSnapshot.data == 'admin';

            return AppScaffold(
              title: 'Add Expense',
              child: StreamBuilder<List<GroupMember>>(
                stream: repo.watchMembers(widget.groupId),
                builder: (context, membersSnapshot) {
                  final members = membersSnapshot.data ?? [];

                  // Keep state consistent
                  if (_participants.isNotEmpty && _paidBy != null && !_participants.contains(_paidBy)) {
                    _paidBy = _participants.first;
                  }

                  final participantMembers = members.where((m) => _participants.contains(m.id)).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Main Transaction Details ---
                        TextField(
                          controller: _amountController,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: 'PKR ',
                            prefixStyle: theme.textTheme.titleLarge?.copyWith(color: colorScheme.outline),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Category & Description Row ---
                        // --- Category & Description Row (Fixed for Overflow) ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5, // Gives Category slightly less space
                              child: StreamBuilder<List<String>>(
                                stream: repo.watchCategories(widget.groupId),
                                builder: (context, snap) {
                                  final cats = snap.data ?? ['breakfast', 'lunch', 'dinner', 'transport'];
                                  if (!cats.contains(_category)) _category = cats.first;
                                  return DropdownButtonFormField<String>(
                                    value: _category,
                                    isExpanded: true, // Prevents text from pushing the dropdown width
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                      prefixIcon: Icon(Icons.category_outlined, size: 20),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    items: cats.map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c, overflow: TextOverflow.ellipsis) // Truncates if too long
                                    )).toList(),
                                    onChanged: (v) => setState(() => _category = v!),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8), // Reduced gap slightly
                            Expanded(
                              flex: 6, // Gives Note slightly more space
                              child: TextField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Note',
                                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // --- Payer Section ---
                        Text("Paid By", style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _paidBy,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                            hintText: 'Select who paid',
                          ),
                          items: participantMembers.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                          onChanged: participantMembers.isEmpty ? null : (v) => setState(() => _paidBy = v),
                        ),
                        if (_participants.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 12),
                            child: Text('Add participants first to select a payer', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                          ),
                        const SizedBox(height: 32),

                        // --- Participants List ---
                        Text("Split Between", style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: members.map((m) {
                              final isSelected = _participants.contains(m.id);
                              return CheckboxListTile(
                                value: isSelected,
                                checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (v) {
                                  setState(() {
                                    v == true ? _participants.add(m.id) : _participants.remove(m.id);
                                  });
                                },
                                title: Text(m.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                secondary: CircleAvatar(
                                  backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                  child: Text(m.initials, style: TextStyle(color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 32),

                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(color: colorScheme.errorContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                            child: Text(_errorMessage!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
                          ),

                        BusyButton(
                          busy: _isBusy,
                          onPressed: () => _saveExpense(group, isAdmin),
                          text: isAdmin && group.adminBypass ? 'Save (Auto-approved)' : 'Add Expense',
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}