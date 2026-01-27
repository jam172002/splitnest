import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  bool _requireApproval = true;
  bool _adminBypass = true;
  String _approvalMode = 'any';
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = "Please enter a group name");
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final auth = context.read<AuthRepo>();
      final u = auth.currentUser!;
      final gid = await context.read<GroupRepo>().createGroup(
        name: _name.text.trim(),
        uid: u.uid,
        email: u.email ?? '',
        requireApproval: _requireApproval,
        adminBypass: _adminBypass,
        approvalMode: _approvalMode,
      );
      if (mounted) context.go('/group/$gid');
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Create Group',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Group Identity Section ---
            Text(
              "Group Details",
              style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Flatmates, Road Trip',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(height: 32),

            // --- Settings Section ---
            Text(
              "Management Rules",
              style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _requireApproval,
                    onChanged: (v) => setState(() => _requireApproval = v),
                    title: const Text('Require Approvals'),
                    subtitle: const Text('Entries must be endorsed by members'),
                    secondary: const Icon(Icons.verified_user_outlined),
                  ),
                  const Divider(indent: 64, height: 1),
                  SwitchListTile(
                    value: _adminBypass,
                    onChanged: (v) => setState(() => _adminBypass = v),
                    title: const Text('Admin Bypass'),
                    subtitle: const Text('Your entries are auto-approved'),
                    secondary: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Logic Section ---
            DropdownButtonFormField<String>(
              value: _approvalMode,
              items: const [
                DropdownMenuItem(value: 'any', child: Text('Any member can approve')),
                DropdownMenuItem(value: 'all', child: Text('Everyone must approve')),
                DropdownMenuItem(value: 'admin_only', child: Text('Only Admin approves')),
              ],
              onChanged: (v) => setState(() => _approvalMode = v ?? 'any'),
              decoration: const InputDecoration(
                labelText: 'Approval Logic',
                prefixIcon: Icon(Icons.rule_rounded),
              ),
            ),

            const SizedBox(height: 32),

            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _err!,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),

            BusyButton(
              busy: _busy,
              onPressed: _create,
              text: 'Launch Group',
            ),
          ],
        ),
      ),
    );
  }
}