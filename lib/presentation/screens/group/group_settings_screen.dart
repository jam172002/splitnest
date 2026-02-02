import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  bool _busy = false;
  String? _err;

  bool? _requireApproval;
  bool? _adminBypass;
  String? _approvalMode;

  void _showInviteQR(BuildContext context, String groupId) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text('Group Invite QR',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Your friend can scan this code to join the group instantly.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: groupId,
                version: QrVersions.auto,
                size: 220.0,
                eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.circle, color: colorScheme.primary),
                dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text('Group ID: $groupId',
                style: theme.textTheme.labelMedium
                    ?.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, GroupRepo repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'This will permanently delete the group and all its data.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      await repo.deleteGroup(widget.groupId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted successfully')),
      );

      // Navigate to Groups home screen
      context.go('/');

    } catch (e) {
      if (mounted) {
        setState(() => _err = e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repo = context.read<GroupRepo>();
    final auth = context.watch<AuthRepo>();
    final uid = auth.currentUser?.uid ?? '';

    return StreamBuilder(
      stream: repo.watchGroup(widget.groupId),
      builder: (context, snap) {
        final g = snap.data;
        if (g == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAdmin = g.createdBy == uid;

        _requireApproval ??= g.requireApproval;
        _adminBypass ??= g.adminBypass;
        _approvalMode ??= g.approvalMode;

        return AppScaffold(
          title: 'Group Settings',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(context, 'Invite Members'),
                FilledButton.tonal(
                  onPressed: () => _showInviteQR(context, widget.groupId),
                  child: const Text('Show QR Code'),
                ),

                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Workflow Automation'),
                SwitchListTile(
                  value: _requireApproval!,
                  onChanged: (v) => setState(() => _requireApproval = v),
                  title: const Text('Require Approvals'),
                ),
                SwitchListTile(
                  value: _adminBypass!,
                  onChanged: (v) => setState(() => _adminBypass = v),
                  title: const Text('Admin Bypass'),
                ),

                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Approval Policy'),
                _buildModeOption(
                  context: context,
                  id: 'any',
                  title: 'Any Endorsement',
                  desc: 'One person can approve.',
                  icon: Icons.person_outline,
                ),
                _buildModeOption(
                  context: context,
                  id: 'all',
                  title: 'Full Consensus',
                  desc: 'Everyone must approve.',
                  icon: Icons.group_outlined,
                ),
                _buildModeOption(
                  context: context,
                  id: 'admin_only',
                  title: 'Admin Only',
                  desc: 'Only admins approve.',
                  icon: Icons.admin_panel_settings_outlined,
                ),

                const SizedBox(height: 32),

                if (isAdmin) ...[
                  _buildSectionHeader(context, 'Danger Zone'),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _confirmDelete(context, repo),
                    child: const Text('Delete Group'),
                  ),
                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────
                  //  PASTE THE NEW RESET BUTTON BLOCK HERE
                  // ────────────────────────────────────────────────
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Reset Group'),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    label: const Text('Clear All Expenses & Reset Balances'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.15),
                      foregroundColor: Colors.orange.shade800,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reset Group Balances'),
                          content: const Text(
                            'This will delete all expense and settlement history and reset balances to zero.\n\n'
                                'The group name, members, and ID remain unchanged.\n\n'
                                'Only do this after everyone has settled payments outside the app.\n\n'
                                'This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Reset Group'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      setState(() => _busy = true);

                      try {
                        await repo.resetGroupBalances(widget.groupId); // You need to implement this method
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Group has been reset successfully')),
                          );
                          context.go('/group/${widget.groupId}'); // or context.go('/') if you prefer
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _err = 'Failed to reset: $e');
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
                  ),
                ],
                if (_err != null)
                  Text(
                    _err!,
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),

                BusyButton(
                  busy: _busy,
                  onPressed: () async {
                    setState(() => _busy = true);
                    await repo.updateApprovalSettings(
                      groupId: widget.groupId,
                      requireApproval: _requireApproval!,
                      adminBypass: _adminBypass!,
                      approvalMode: _approvalMode!,
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  text: 'Save Changes',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required String id,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _approvalMode == id;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(desc),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () => setState(() => _approvalMode = id),
    );
  }

}
