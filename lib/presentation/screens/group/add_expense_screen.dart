import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart'; //  for PayerPortion
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final String? txId;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    this.txId,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _PayerRow {
  String? uid;
  final TextEditingController amountCtrl = TextEditingController();
  void dispose() => amountCtrl.dispose();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Logic to hide hint on tap
  final _amountFocus = FocusNode();

  String _category = 'breakfast';
  final Set<String> _participants = {};

  //  Multi payer rows
  final List<_PayerRow> _payerRows = [];

  //  NEW: Unequal split
  bool _unequalSplit = false;

  // For per-member share inputs (only used when _unequalSplit == true)
  final Map<String, TextEditingController> _shareCtrls = {};

  bool _isBusy = false;
  bool _isLoadingEdit = false;
  String? _errorMessage;

  bool get _isEditing => widget.txId != null;

  @override
  void initState() {
    super.initState();

    _amountFocus.addListener(() {
      if (mounted) setState(() {});
    });

    _payerRows.add(_PayerRow());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isEditing) {
        _loadExpenseForEdit();
        return;
      }
      final myId = context.read<AuthRepo>().currentUser?.uid;
      if (myId != null) {
        setState(() => _payerRows.first.uid = myId);
      }
    });
  }

  Future<void> _loadExpenseForEdit() async {
    setState(() {
      _isLoadingEdit = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<GroupRepo>();
      final uid = context.read<AuthRepo>().currentUser!.uid;
      if (await repo.roleOf(widget.groupId, uid) != 'admin') {
        throw Exception('Only group admins can edit expenses');
      }

      final tx = await repo.getTx(widget.groupId, widget.txId!);
      if (!mounted) return;
      if (tx == null) {
        throw Exception('Expense not found');
      }
      if (tx.type != 'expense') {
        throw Exception('Only expenses can be edited');
      }

      for (final row in _payerRows) {
        row.dispose();
      }
      _payerRows.clear();

      _amountController.text = tx.amount.toStringAsFixed(2);
      _descriptionController.text = tx.description ?? '';
      _category = tx.category ?? 'other';
      _participants
        ..clear()
        ..addAll(tx.participants);
      _unequalSplit = tx.participantShares.isNotEmpty;

      for (final payer in tx.payers) {
        final row = _PayerRow()..uid = payer.uid;
        row.amountCtrl.text = payer.amount.toStringAsFixed(2);
        _payerRows.add(row);
      }
      if (_payerRows.isEmpty) {
        final row = _PayerRow()..uid = tx.paidBy;
        row.amountCtrl.text = tx.amount.toStringAsFixed(2);
        _payerRows.add(row);
      }

      for (final entry in tx.participantShares.entries) {
        _shareCtrlFor(entry.key).text = entry.value.toStringAsFixed(2);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _isLoadingEdit = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocus.dispose();
    for (final r in _payerRows) {
      r.dispose();
    }
    for (final c in _shareCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPayerRow() => setState(() => _payerRows.add(_PayerRow()));

  void _removePayerRow(int index) {
    if (_payerRows.length <= 1) return;
    final r = _payerRows.removeAt(index);
    r.dispose();
    setState(() {});
  }

  double _sumPayers() {
    double sum = 0;
    for (final r in _payerRows) {
      final v = double.tryParse(r.amountCtrl.text.trim()) ?? 0;
      sum += v;
    }
    return sum;
  }

  TextEditingController _shareCtrlFor(String uid) {
    return _shareCtrls.putIfAbsent(uid, () => TextEditingController());
  }

  void _cleanupShareCtrls(List<GroupMember> members) {
    final valid = members.map((m) => m.id).toSet();
    final toRemove = _shareCtrls.keys.where((k) => !valid.contains(k)).toList();
    for (final k in toRemove) {
      _shareCtrls[k]?.dispose();
      _shareCtrls.remove(k);
    }
  }

  /// Builds participantShares if unequal split is enabled.
  /// Rule:
  /// - You can enter a fixed amount for any selected participant(s)
  /// - Remaining amount is split equally among the other selected participants
  /// - If you fill all selected participants, their sum must equal total
  Map<String, double>? _buildParticipantShares({
    required double totalAmount,
    required List<String> selectedParticipantUids,
  }) {
    if (!_unequalSplit) return null;

    final parts = selectedParticipantUids;
    if (parts.isEmpty) return null;

    const tol = 0.01;

    final fixed = <String, double>{};
    for (final uid in parts) {
      final raw = _shareCtrls[uid]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final v = double.tryParse(raw);
      if (v == null) continue;
      if (v > 0) fixed[uid] = v;
    }

    final fixedSum = fixed.values.fold<double>(0.0, (a, b) => a + b);

    if (fixedSum - totalAmount > tol) {
      throw Exception('Participants total cannot exceed the expense amount');
    }

    final remainingUids = parts.where((u) => !fixed.containsKey(u)).toList();
    final remaining = totalAmount - fixedSum;

    final shares = <String, double>{};

    // If all have values, sum must match total
    if (remainingUids.isEmpty) {
      if ((fixedSum - totalAmount).abs() > tol) {
        throw Exception('Participants total must equal the expense amount');
      }
      shares.addAll(fixed);
      return shares;
    }

    // Distribute remaining equally to others
    final each = remaining / remainingUids.length;
    for (final uid in remainingUids) {
      shares[uid] = each;
    }
    shares.addAll(fixed);

    // Final safety: sum must match total
    final sumShares = shares.values.fold<double>(0.0, (a, b) => a + b);
    if ((sumShares - totalAmount).abs() > tol) {
      throw Exception('Participants distribution does not match total');
    }

    return shares;
  }

  Future<void> _saveExpense(
      Group group, bool isAdmin, List<GroupMember> members) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        throw Exception('Enter a valid amount');
      }

      if (_participants.isEmpty) {
        throw Exception('Select at least one participant');
      }

      //  build payers
      final payers = <PayerPortion>[];
      final seen = <String>{};

      for (final r in _payerRows) {
        final uid = r.uid;
        final partAmt = double.tryParse(r.amountCtrl.text.trim());

        if (uid == null || uid.trim().isEmpty) continue;
        if (partAmt == null || partAmt <= 0) continue;

        // avoid duplicates: if same uid entered twice, merge amounts (graceful)
        if (seen.contains(uid)) {
          final i = payers.indexWhere((p) => p.uid == uid);
          payers[i] =
              PayerPortion(uid: uid, amount: payers[i].amount + partAmt);
        } else {
          payers.add(PayerPortion(uid: uid, amount: partAmt));
          seen.add(uid);
        }
      }

      if (payers.isEmpty) throw Exception('Add at least one payer with amount');

      final sumPayers = payers.fold<double>(0, (a, p) => a + p.amount);
      if ((sumPayers - amount).abs() > 0.01) {
        throw Exception('Payers total must equal the expense amount');
      }

      //  participant shares (optional)
      final participantShares = _buildParticipantShares(
        totalAmount: amount,
        selectedParticipantUids: _participants.toList(),
      );

      //  Backward compatibility: keep a "primary" paidBy
      final paidBy = payers.first.uid;

      final authRepo = context.read<AuthRepo>();
      final myId = authRepo.currentUser!.uid;

      final repo = context.read<GroupRepo>();
      if (_isEditing) {
        if (!isAdmin) {
          throw Exception('Only group admins can edit expenses');
        }
        await repo.updateExpense(
          groupId: widget.groupId,
          txId: widget.txId!,
          currentUid: myId,
          amount: amount,
          category: _category,
          paidBy: paidBy,
          payers: payers,
          participants: _participants.toList(),
          participantShares: participantShares,
          description: _descriptionController.text.trim(),
        );
      } else {
        await repo.addExpense(
          groupId: widget.groupId,
          group: group,
          amount: amount,
          category: _category,
          paidBy: paidBy,
          payers: payers,
          participants: _participants.toList(),
          participantShares: participantShares,
          description: _descriptionController.text.trim(),
          at: DateTime.now(),
          createdBy: myId,
          isAdmin: isAdmin,
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
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
        if (!groupSnapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final group = groupSnapshot.data!;

        return FutureBuilder<String>(
          future: repo.roleOf(widget.groupId, myId),
          builder: (context, roleSnapshot) {
            final isAdmin = roleSnapshot.data == 'admin';

            if (_isEditing && roleSnapshot.hasData && !isAdmin) {
              return const Scaffold(
                body:
                    Center(child: Text('Only group admins can edit expenses.')),
              );
            }

            return AppScaffold(
              title: _isEditing ? 'Edit Expense' : 'Add Expense',
              child: StreamBuilder<List<GroupMember>>(
                stream: repo.watchMembers(widget.groupId),
                builder: (context, membersSnapshot) {
                  final members = membersSnapshot.data ?? [];

                  // keep selected participants valid if members list changes
                  _participants
                      .removeWhere((id) => members.every((m) => m.id != id));

                  // keep payer uid valid if member removed (graceful)
                  for (final r in _payerRows) {
                    if (r.uid != null && members.every((m) => m.id != r.uid)) {
                      r.uid = null;
                    }
                  }

                  // cleanup share controllers
                  _cleanupShareCtrls(members);

                  final payerTotal = _sumPayers();
                  final totalAmount =
                      double.tryParse(_amountController.text.trim()) ?? 0;

                  // preview participant shares when unequal split is on
                  Map<String, double>? previewShares;
                  String? previewErr;
                  if (_unequalSplit &&
                      totalAmount > 0 &&
                      _participants.isNotEmpty) {
                    try {
                      previewShares = _buildParticipantShares(
                        totalAmount: totalAmount,
                        selectedParticipantUids: _participants.toList(),
                      );
                    } catch (e) {
                      previewErr = e.toString().replaceFirst('Exception: ', '');
                    }
                  }

                  if (_isLoadingEdit) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Hero Amount Input ---
                        TextField(
                          controller: _amountController,
                          focusNode: _amountFocus,
                          textAlign: TextAlign.center,
                          autofocus: !_isEditing,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _amountFocus.hasFocus ? '' : '0.00',
                            hintStyle: theme.textTheme.displayMedium?.copyWith(
                              color: colorScheme.outlineVariant,
                              fontWeight: FontWeight.bold,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'PKR',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 0, minHeight: 0),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Category & Note Row ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: StreamBuilder<List<String>>(
                                stream: repo.watchCategories(widget.groupId),
                                builder: (context, snap) {
                                  final cats = [
                                    ...(snap.data ??
                                        [
                                          'breakfast',
                                          'lunch',
                                          'dinner',
                                          'transport'
                                        ]),
                                  ];
                                  if (!cats.contains(_category))
                                    cats.add(_category);
                                  return DropdownButtonFormField<String>(
                                    initialValue: _category,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                      prefixIcon: Icon(Icons.category_outlined,
                                          size: 20),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                    ),
                                    items: cats
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _category = v!),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 6,
                              child: TextField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Note',
                                  prefixIcon:
                                      Icon(Icons.notes_rounded, size: 20),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        //  Multi Payers
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Paid By (Multiple Allowed)",
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: colorScheme.primary),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addPayerRow,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add payer'),
                            )
                          ],
                        ),
                        const SizedBox(height: 10),

                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < _payerRows.length; i++) ...[
                                if (i != 0)
                                  const Divider(
                                      height: 1, indent: 16, endIndent: 16),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _payerRows[i].uid,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Payer',
                                            prefixIcon: Icon(
                                                Icons.person_outline_rounded,
                                                size: 18),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10),
                                          ),
                                          items: members
                                              .map((m) => DropdownMenuItem(
                                                    value: m.id,
                                                    child: Text(m.name,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                  ))
                                              .toList(),
                                          onChanged: (v) => setState(
                                              () => _payerRows[i].uid = v),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 4,
                                        child: TextField(
                                          controller: _payerRows[i].amountCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                            labelText: 'Amount',
                                            prefixIcon: Icon(
                                                Icons.payments_outlined,
                                                size: 18),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        tooltip: 'Remove payer',
                                        onPressed: _payerRows.length <= 1
                                            ? null
                                            : () => _removePayerRow(i),
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: _payerRows.length <= 1
                                              ? colorScheme.outlineVariant
                                              : colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // small summary line (helps user match totals)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Payers total: ${payerTotal.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: colorScheme.outline),
                              ),
                            ),
                            Text(
                              'Total: ${totalAmount.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: (totalAmount > 0 &&
                                        (payerTotal - totalAmount).abs() <=
                                            0.01)
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        // --- Participants List ---
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Split Between",
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: colorScheme.primary),
                              ),
                            ),
                            //  Unequal distribution toggle
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Unequal',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Switch(
                                  value: _unequalSplit,
                                  onChanged: (v) =>
                                      setState(() => _unequalSplit = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: members.map((m) {
                              final isSelected = _participants.contains(m.id);
                              final shareCtrl = _shareCtrlFor(m.id);

                              return Column(
                                children: [
                                  CheckboxListTile(
                                    value: isSelected,
                                    checkboxShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _participants.add(m.id);
                                        } else {
                                          _participants.remove(m.id);
                                          // optional: clear share when unselected
                                          shareCtrl.text = '';
                                        }
                                      });
                                    },
                                    title: Text(
                                      m.name,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    secondary: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.surfaceContainerHighest,
                                      child: Text(
                                        m.initials,
                                        style: TextStyle(
                                          color: isSelected
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),

                                  //  NEW UI: per-user expense input (only when unequal split + selected)
                                  if (_unequalSplit && isSelected)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Amount for ${m.name}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 140,
                                            child: TextField(
                                              controller: shareCtrl,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              onChanged: (_) => setState(() {}),
                                              decoration: const InputDecoration(
                                                labelText: 'Share',
                                                prefixIcon: Icon(
                                                    Icons
                                                        .pie_chart_outline_rounded,
                                                    size: 18),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // divider
                                  if (m.id != members.last.id)
                                    const Divider(
                                        height: 1, indent: 16, endIndent: 16),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                        //  Preview (only when unequal)
                        if (_unequalSplit) ...[
                          const SizedBox(height: 10),
                          if (previewErr != null)
                            Text(
                              previewErr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else if (previewShares != null)
                            Text(
                              'Auto split preview: ${previewShares.entries.take(3).map((e) => '${members.firstWhere((m) => m.id == e.key, orElse: () => GroupMember(id: e.key, name: e.key, role: "member", joinedAt: DateTime.now())).name}: ${e.value.toStringAsFixed(2)}').join(' • ')}'
                              '${previewShares.length > 3 ? ' …' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],

                        const SizedBox(height: 32),

                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        BusyButton(
                          busy: _isBusy,
                          onPressed: () =>
                              _saveExpense(group, isAdmin, members),
                          text: _isEditing
                              ? 'Save Changes'
                              : isAdmin && group.adminBypass
                                  ? 'Save (Auto-approved)'
                                  : 'Add Expense',
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
