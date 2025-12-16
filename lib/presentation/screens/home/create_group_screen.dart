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
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
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
    return AppScaffold(
      title: 'Create Group',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Group name'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _requireApproval,
            onChanged: (v) => setState(() => _requireApproval = v),
            title: const Text('Require approval for member entries'),
          ),
          SwitchListTile(
            value: _adminBypass,
            onChanged: (v) => setState(() => _adminBypass = v),
            title: const Text('Admin entries auto-approved'),
          ),
          if (_err != null)
            Text(_err!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          BusyButton(busy: _busy, onPressed: _create, text: 'Create'),
        ],
      ),
    );
  }
}
