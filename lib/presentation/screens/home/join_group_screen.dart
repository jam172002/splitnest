import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  final _idController = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  // --- The QR Scanner Overlay ---
  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan Group QR'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? code = barcodes.first.rawValue;
              if (code != null) {
                _idController.text = code;
                Navigator.pop(context); // Close scanner
                _join(); // Auto-trigger join
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _join() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    setState(() { _busy = true; _err = null; });
    try {
      final auth = context.read<AuthRepo>();
      final repo = context.read<GroupRepo>();
      final currentUser = auth.currentUser;

      await repo.addMember(
        groupId: id, // Your text field controller value
        name: currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'New Member',
        role: 'member',
        uid: currentUser!.uid, // Use the actual UID of the person joining
      );

      if (mounted) context.pushReplacement('/group/$id');
    } catch (e) {
      setState(() => _err = "Could not find or join group. Check the ID.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Join Group',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.group_add_outlined, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Enter a Group ID or scan a QR code to join your friends.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),

            // Text Input
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: 'Group ID',
                hintText: 'e.g. xYz123...',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  color: colorScheme.primary,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 16),

            // Scan Button (Alternative entry)
            OutlinedButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan QR Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const Spacer(),

            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_err!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
              ),

            BusyButton(
              busy: _busy,
              onPressed: _join,
              text: 'Join Group',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}