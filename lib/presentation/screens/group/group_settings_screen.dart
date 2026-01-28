import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  // Local state to track changes before saving
  bool? _requireApproval;
  bool? _adminBypass;
  String? _approvalMode;

  // --- QR Invite Logic ---
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
                    ?.copyWith(letterSpacing: 1.2, color: colorScheme.outline)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repo = context.read<GroupRepo>();

    return StreamBuilder(
      stream: repo.watchGroup(widget.groupId),
      builder: (context, snap) {
        final g = snap.data;
        if (g == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        // Initialize local state from DB if not already set by user
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
                // --- NEW: QR Invite Section ---
                _buildSectionHeader(context, 'Invite Members'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 40, color: colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Group QR Code',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            Text('Let others scan to join',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _showInviteQR(context, widget.groupId),
                        child: const Text('Show'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                _buildSectionHeader(context, 'Workflow Automation'),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _requireApproval!,
                        onChanged: (v) => setState(() => _requireApproval = v),
                        title: const Text('Require Approvals'),
                        subtitle: const Text('New entries must be verified before affecting balances.'),
                        secondary: Icon(Icons.verified_user_outlined, color: colorScheme.primary),
                      ),
                      const Divider(indent: 64, endIndent: 16, height: 1),
                      SwitchListTile(
                        value: _adminBypass!,
                        onChanged: (v) => setState(() => _adminBypass = v),
                        title: const Text('Admin Bypass'),
                        subtitle: const Text('Expenses added by admins skip the approval queue.'),
                        secondary: Icon(Icons.bolt_rounded, color: Colors.amber.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                _buildSectionHeader(context, 'Approval Policy'),
                const SizedBox(height: 8),
                _buildModeOption(
                  context: context,
                  id: 'any',
                  title: 'Any Endorsement',
                  desc: 'One person (any participant) can approve a transaction.',
                  icon: Icons.person_outline,
                ),
                _buildModeOption(
                  context: context,
                  id: 'all',
                  title: 'Full Consensus',
                  desc: 'Every participant in the expense must approve it.',
                  icon: Icons.group_outlined,
                ),
                _buildModeOption(
                  context: context,
                  id: 'admin_only',
                  title: 'Admin Only',
                  desc: 'Only group admins have the power to approve entries.',
                  icon: Icons.admin_panel_settings_outlined,
                ),

                const SizedBox(height: 32),
                if (_err != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_err!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
                  ),

                BusyButton(
                  busy: _busy,
                  onPressed: () async {
                    setState(() { _busy = true; _err = null; });
                    try {
                      await repo.updateApprovalSettings(
                        groupId: widget.groupId,
                        requireApproval: _requireApproval!,
                        adminBypass: _adminBypass!,
                        approvalMode: _approvalMode!,
                      );
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      setState(() => _err = e.toString());
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _approvalMode = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.outline),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                  )),
                  Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? colorScheme.onPrimaryContainer.withOpacity(0.8) : colorScheme.outline,
                  )),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}