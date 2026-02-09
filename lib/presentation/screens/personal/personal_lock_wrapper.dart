import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'personal_lock_controller.dart';

class PersonalLockWrapper extends StatelessWidget {
  final Widget child;
  const PersonalLockWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<PersonalLockController>(
      builder: (context, lock, _) {
        final locked = lock.isLocked;

        Widget content = child;

        // ✅ Any touch/scroll resets the inactivity countdown (only if unlocked)
        content = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => lock.bumpInactivity(),
          onPointerMove: (_) => lock.bumpInactivity(),
          onPointerSignal: (_) => lock.bumpInactivity(), // mouse wheel / trackpad
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              lock.bumpInactivity();
              return false;
            },
            child: content,
          ),
        );

        return Stack(
          children: [
            IgnorePointer(
              ignoring: locked,
              child: content,
            ),

            // ✅ AnimatedSwitcher child must NOT be Positioned
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: locked
                  ? const _LockedOverlay(key: ValueKey('locked'))
                  : const SizedBox.shrink(key: ValueKey('unlocked')),
            ),
          ],
        );
      },
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({super.key});

  Future<void> _unlock(BuildContext context) async {
    final lock = context.read<PersonalLockController>();

    // 1) biometric first
    final canBio = await lock.canBiometric();
    if (canBio) {
      final ok = await lock.authBiometric();
      if (ok) {
        lock.unlockFor(lock.lockDuration);
        lock.bumpInactivity(); // start inactivity tracking immediately
        return;
      }
    }

    // 2) fallback to PIN
    final hasPin = await lock.hasPin();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinDialog(isSetup: !hasPin),
    );

    if (pin == null) return;

    if (!hasPin) {
      await lock.setPin(pin);
      lock.unlockFor(lock.lockDuration);
      return;
    }

    final ok = await lock.verifyPin(pin);
    if (ok) {
      lock.unlockFor(lock.lockDuration);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox.expand( // ✅ makes it fill Stack space
      child: Material(
        color: cs.surface.withValues(alpha: 0.99),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 46, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Personal tab is locked',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock with fingerprint / device lock / PIN.\nAuto-locks after 10 seconds.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _unlock(context),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
    );
  }
}

class _PinDialog extends StatefulWidget {
  final bool isSetup;
  const _PinDialog({required this.isSetup});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isSetup ? 'Set PIN' : 'Enter PIN'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'PIN (4-6 digits)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final pin = ctrl.text.trim();
            if (pin.length < 4) return;
            Navigator.pop(context, pin);
          },
          child: Text(widget.isSetup ? 'Save' : 'Unlock'),
        ),
      ],
    );
  }
}