import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_security_service.dart';
import 'privacy_screen.dart';

class AppSecurityGate extends ConsumerStatefulWidget {
  const AppSecurityGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppSecurityGate> createState() => _AppSecurityGateState();
}

class _AppSecurityGateState extends ConsumerState<AppSecurityGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(privacySettingsProvider, (previous, next) {
      NativeSecurityService.setRecentAppsPrivacy(next.hideInRecentApps);
      if (next.isLoaded && previous?.isLoaded != true && next.biometricLock) {
        _lockAndAuthenticate();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final biometricEnabled = ref.read(privacySettingsProvider).biometricLock;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
      if (biometricEnabled && mounted) setState(() => _locked = true);
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _wasBackgrounded &&
        biometricEnabled) {
      _wasBackgrounded = false;
      _lockAndAuthenticate();
    }
  }

  Future<void> _lockAndAuthenticate() async {
    if (_authenticating || !mounted) return;
    setState(() {
      _locked = true;
      _authenticating = true;
    });
    final result = await NativeSecurityService.authenticate();
    if (!mounted) return;
    if (result == BiometricAuthResult.unavailable) {
      await ref.read(privacySettingsProvider.notifier).setBiometricLock(false);
    }
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = result == BiometricAuthResult.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              color: const Color(0xFF0D1117),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded,
                            color: Color(0xFF00C850), size: 64),
                        const SizedBox(height: 18),
                        const Text(
                          'พี่เงินถูกล็อกอยู่',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ยืนยันตัวตนด้วย Face ID หรือลายนิ้วมือเพื่อดำเนินการต่อ',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 210,
                          child: ElevatedButton.icon(
                            onPressed:
                                _authenticating ? null : _lockAndAuthenticate,
                            icon: _authenticating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.fingerprint_rounded),
                            label: const Text('ยืนยันตัวตน'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
