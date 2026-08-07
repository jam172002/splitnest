import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../personal/personal_lock_controller.dart';
import '../../widgets/app_scaffold.dart';

class PersonalExpensesSettingsScreen extends StatelessWidget {
  const PersonalExpensesSettingsScreen({super.key});

  Future<String?> _askForPin(
    BuildContext context, {
    required String title,
    required String action,
    bool confirmPin = false,
  }) async {
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'PIN (4-6 digits)',
                  errorText: error,
                ),
              ),
              if (confirmPin)
                TextField(
                  controller: second,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = first.text.trim();
                if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                  setState(() => error = 'Use 4-6 digits');
                  return;
                }
                if (confirmPin && pin != second.text.trim()) {
                  setState(() => error = 'PINs do not match');
                  return;
                }
                Navigator.pop(dialogContext, pin);
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    first.dispose();
    second.dispose();
    return result;
  }

  Future<bool> _verifyCurrentPin(
    BuildContext context,
    PersonalLockController lock,
  ) async {
    final pin = await _askForPin(
      context,
      title: 'Enter current PIN',
      action: 'Verify',
    );
    if (pin == null) return false;
    if (await lock.verifyPin(pin)) return true;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong PIN')),
      );
    }
    return false;
  }

  Future<void> _toggleLock(
    BuildContext context,
    PersonalLockController lock,
    bool enabled,
  ) async {
    if (enabled) {
      if (!await lock.hasPin()) {
        if (!context.mounted) return;
        final pin = await _askForPin(
          context,
          title: 'Set Personal Expenses PIN',
          action: 'Enable Lock',
          confirmPin: true,
        );
        if (pin == null) return;
        await lock.setPin(pin);
      }
      await lock.setEnabled(true);
      return;
    }

    if (!await _verifyCurrentPin(context, lock)) return;
    await lock.setEnabled(false);
  }

  Future<void> _changePin(
    BuildContext context,
    PersonalLockController lock,
  ) async {
    final hasPin = await lock.hasPin();
    if (!context.mounted) return;
    if (hasPin && !await _verifyCurrentPin(context, lock)) return;
    if (!context.mounted) return;
    final pin = await _askForPin(
      context,
      title: 'Set new PIN',
      action: 'Save PIN',
      confirmPin: true,
    );
    if (pin == null) return;
    await lock.setPin(pin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal Expenses PIN updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<PersonalLockController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppScaffold(
      title: 'Personal Expenses',
      child: !lock.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    lock.isEnabled
                        ? 'Personal expenses are protected.'
                        : 'Personal expenses are currently unlocked. Enable the lock to require a PIN or biometrics.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lock Personal Expenses'),
                  subtitle: const Text(
                      'Require authentication when opening the Personal tab'),
                  value: lock.isEnabled,
                  onChanged: (value) => _toggleLock(context, lock, value),
                ),
                const Divider(),
                FutureBuilder<bool>(
                  future: lock.canBiometric(),
                  builder: (context, snapshot) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use biometrics'),
                    subtitle: Text(
                      snapshot.data == true
                          ? 'Use fingerprint or face authentication before PIN'
                          : 'Biometrics are unavailable on this device',
                    ),
                    value: lock.useBiometric && snapshot.data == true,
                    onChanged: lock.isEnabled && snapshot.data == true
                        ? lock.setUseBiometric
                        : null,
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-lock after'),
                  subtitle: Text(_durationLabel(lock.lockDuration)),
                  trailing: DropdownButton<int>(
                    value: lock.lockDuration.inSeconds,
                    onChanged: lock.isEnabled
                        ? (seconds) {
                            if (seconds != null) {
                              lock.setLockDuration(Duration(seconds: seconds));
                            }
                          }
                        : null,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 sec')),
                      DropdownMenuItem(value: 30, child: Text('30 sec')),
                      DropdownMenuItem(value: 60, child: Text('1 min')),
                      DropdownMenuItem(value: 300, child: Text('5 min')),
                      DropdownMenuItem(value: 900, child: Text('15 min')),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: lock.isEnabled,
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('Change PIN'),
                  onTap:
                      lock.isEnabled ? () => _changePin(context, lock) : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: lock.isEnabled,
                  leading: const Icon(Icons.lock_clock_outlined),
                  title: const Text('Lock now'),
                  subtitle: const Text(
                      'Require authentication next time the Personal tab opens'),
                  onTap: lock.isEnabled
                      ? () {
                          lock.lockNow();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Personal Expenses locked')),
                          );
                        }
                      : null,
                ),
              ],
            ),
    );
  }

  String _durationLabel(Duration duration) {
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'} of inactivity';
    }
    return '${duration.inSeconds} seconds of inactivity';
  }
}
