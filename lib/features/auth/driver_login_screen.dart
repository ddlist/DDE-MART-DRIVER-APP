// DDE-Mart driver app — OTP sign-in screen (original).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import 'driver_auth_api.dart';

class DriverLoginScreen extends ConsumerStatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  ConsumerState<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends ConsumerState<DriverLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiMessage(e))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver sign in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Your dispatcher registers your number. Sign in with a code.'),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final debug = await ref
                          .read(driverAuthApiProvider)
                          .otpRequest(_phone.text.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              debug == null ? 'Code sent.' : 'Code sent (debug: $debug).',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) _fail(e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Send code'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '6-digit code'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final payload =
                          await ref.read(driverAuthApiProvider).otpVerify(
                                phone: _phone.text.trim(),
                                code: _code.text.trim(),
                              );
                      await ref.read(authStoreProvider.notifier).signIn(
                            token: '${payload['token']}',
                            name: '${payload['name'] ?? ''}',
                            phone: _phone.text.trim(),
                          );
                      if (context.mounted) context.go('/jobs');
                    } catch (e) {
                      if (context.mounted) _fail(e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Verify & sign in'),
          ),
        ],
      ),
    );
  }
}
