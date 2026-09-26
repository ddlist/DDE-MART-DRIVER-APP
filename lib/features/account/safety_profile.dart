// DDE-Mart driver app — SOS + profile (original).
//
// POST /driver/sos {latitude, longitude, order_ref?} raises an alert the
// admin safety inbox triages. Coordinates come from the device GPS once the
// location plugin lands — until then the driver can type or paste them.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/push.dart';
import '../auth/driver_auth_api.dart';
import '../jobs/jobs.dart';

class SosApi {
  SosApi(this._dio);

  final Dio _dio;

  Future<void> raise({
    required double latitude,
    required double longitude,
    String? orderRef,
  }) async {
    await _dio.post('/driver/sos', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (orderRef != null && orderRef.isNotEmpty) 'order_ref': orderRef,
    });
  }
}

final sosApiProvider = Provider<SosApi>(
  (ref) => SosApi(ref.watch(dioProvider)),
);

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _order = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Emergency SOS. Sends your location to DDE-Mart safety staff.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lat,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Latitude'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lng,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Longitude'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _order,
          decoration: const InputDecoration(labelText: 'Order ref (optional)'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _busy
              ? null
              : () async {
                  final lat = double.tryParse(_lat.text.trim());
                  final lng = double.tryParse(_lng.text.trim());
                  if (lat == null || lng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter valid coordinates.')),
                    );
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await ref.read(sosApiProvider).raise(
                          latitude: lat,
                          longitude: lng,
                          orderRef: _order.text.trim(),
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SOS sent. Help is on the way.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(apiMessage(e))),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Sending…' : 'SEND SOS'),
        ),
      ],
    );
  }
}

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(jobsApiProvider).profile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final online = (profile?['is_online'] ?? false) == true;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${profile?['name'] ?? auth.name ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${profile?['phone'] ?? auth.phone ?? ''}'),
            Text('Status: ${profile?['status'] ?? '…'}'),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Online for jobs'),
              value: online,
              onChanged: snapshot.hasData
                  ? (value) async {
                      try {
                        await ref.read(jobsApiProvider).availability(value);
                        ref.invalidate(jobsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value ? 'You are online.' : 'You are offline.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(apiMessage(e))),
                          );
                        }
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await ref.read(driverAuthApiProvider).logout();
                } finally {
                  await ref.read(pushServiceProvider).unregister();
                  await ref.read(authStoreProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}
