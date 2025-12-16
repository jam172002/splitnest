import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  bool _requireApproval = true;
  bool _adminBypass = true;
  String _approvalMode = 'any';

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();

    return StreamBuilder(
      stream: repo.watchGroup(widget.groupId),
      builder: (context, snap) {
        final g = snap.data;
        if (g != null) {
          _requireApproval = g.requireApproval;
          _adminBypass = g.adminBypass;
          _approvalMode = g.approvalMode;
        }

        return AppScaffold(
          title: 'Group Settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                value: _requireApproval,
                onChanged: (v) => setState(() => _requireApproval = v),
                title: const Text('Require approvals for member entries'),
              ),
              SwitchListTile(
                value: _adminBypass,
                onChanged: (v) => setState(() => _adminBypass = v),
                title: const Text('Admin entries auto-approved'),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _approvalMode,
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('ANY endorsement approves')),
                  DropdownMenuItem(value: 'all', child: Text('ALL participants must approve')),
                  DropdownMenuItem(value: 'admin_only', child: Text('ADMIN only approves')),
                ],
                onChanged: (v) => setState(() => _approvalMode = v ?? 'any'),
                decoration: const InputDecoration(labelText: 'Approval Mode'),
              ),

              const SizedBox(height: 12),
              if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),

              BusyButton(
                busy: _busy,
                onPressed: () async {
                  setState(() {
                    _busy = true;
                    _err = null;
                  });
                  try {
                    await repo.updateApprovalSettings(
                      groupId: widget.groupId,
                      requireApproval: _requireApproval,
                      adminBypass: _adminBypass,
                      approvalMode: _approvalMode,
                    );
                    if (mounted) Navigator.of(context).pop();
                  } catch (e) {
                    setState(() => _err = e.toString());
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
                text: 'Save',
              ),
            ],
          ),
        );
      },
    );
  }
}
