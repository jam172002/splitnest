import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final auth = context.read<AuthRepo>();
      final u = auth.currentUser!;
      await context.read<GroupRepo>().joinGroup(
        groupId: _code.text.trim(),
        uid: u.uid,
        email: u.email ?? '',
      );
      if (mounted) context.go('/group/${_code.text.trim()}');
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Join Group',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Invite code (Group ID)',
              hintText: 'Example: kJH32k... (from your friend)',
            ),
          ),
          const SizedBox(height: 12),
          if (_err != null)
            Text(_err!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          BusyButton(busy: _busy, onPressed: _join, text: 'Join'),
        ],
      ),
    );
  }
}
