// DDE-Mart driver app — OTP sign-in screen (original).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import 'auth_chrome.dart';
import 'driver_auth_api.dart';

class DriverLoginScreen extends ConsumerStatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  ConsumerState<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends ConsumerState<DriverLoginScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final payload = await ref.read(driverAuthApiProvider).otpVerify(
            phone: _phone.text.trim(),
            code: code,
          );
      await ref.read(authStoreProvider.notifier).signIn(
            token: '${payload['token']}',
            name: '${payload['name'] ?? ''}',
            phone: _phone.text.trim(),
          );
      router.go('/jobs');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AuthHeader(
              title: 'Driver sign in',
              subtitle: 'Your dispatcher registers your number.',
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final debug = await ref
                                  .read(driverAuthApiProvider)
                                  .otpRequest(_phone.text.trim());
                              if (!mounted) return;
                              setState(() => _sent = true);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    debug == null
                                        ? 'Code sent.'
                                        : 'Code sent (debug: $debug).',
                                  ),
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(apiMessage(e))),
                              );
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(_sent ? 'Resend code' : 'Send code'),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Enter code',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    PinCodeField(onCompleted: _verify),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
