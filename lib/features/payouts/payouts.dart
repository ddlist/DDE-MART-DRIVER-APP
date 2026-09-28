// DDE-Mart driver app — payouts API + screen.
//
// GET /driver/payouts (paginated {data, meta}) and POST /driver/payouts
// {amount, method, method_details?}.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

class PayoutsApi {
  PayoutsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _dio.get('/driver/payouts');
    final data = ((response.data as Map)['data'] as List?) ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> request({required double amount, required String method}) async {
    await _dio.post('/driver/payouts', data: {'amount': amount, 'method': method});
  }
}

final payoutsApiProvider = Provider<PayoutsApi>(
  (ref) => PayoutsApi(ref.watch(dioProvider)),
);

final payoutsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(payoutsApiProvider).list();
});

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

const _methods = ['bank', 'paypal', 'stripe', 'razorpay', 'flutterwave', 'cash'];

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  final _amount = TextEditingController();
  String _method = _methods.first;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payouts = ref.watch(payoutsProvider);

    return Column(
      children: [
        GradientHeader(
          title: 'Payouts',
          subtitle: 'Request earnings and track history.',
          icon: Icons.payments_outlined,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              payouts.when(
                loading: () => Row(
                  children: const [
                    StatCard(
                      icon: Icons.account_balance_wallet_outlined,
                      value: '…',
                      label: 'Pending',
                    ),
                    SizedBox(width: 12),
                    StatCard(
                      icon: Icons.check_circle_outline,
                      value: '…',
                      label: 'Paid out',
                      success: true,
                    ),
                  ],
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (rows) {
                  final pending = rows
                      .where((r) =>
                          '${r['status']}'.toLowerCase() != 'paid' &&
                          '${r['status']}'.toLowerCase() != 'completed')
                      .length;
                  final paid = rows.length - pending;
                  return Row(
                    children: [
                      StatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        value: '$pending',
                        label: 'Pending',
                        accent: true,
                      ),
                      const SizedBox(width: 12),
                      StatCard(
                        icon: Icons.check_circle_outline,
                        value: '$paid',
                        label: 'Paid out',
                        success: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              SleekCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Request payout',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      items: [
                        for (final m in _methods)
                          DropdownMenuItem(value: m, child: Text(m))
                      ],
                      onChanged: (value) =>
                          setState(() => _method = value ?? _methods.first),
                      decoration: const InputDecoration(
                        labelText: 'Method',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(_amount.text.trim()) ?? 0;
                              if (amount < 1) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Enter an amount of at least 1.')),
                                );
                                return;
                              }
                              setState(() => _busy = true);
                              try {
                                await ref
                                    .read(payoutsApiProvider)
                                    .request(amount: amount, method: _method);
                                ref.invalidate(payoutsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Payout requested.')),
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
                      child: Text(_busy ? 'Sending…' : 'Request'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              payouts.when(
                loading: () => const Column(
                  children: [
                    ShimmerBox(height: 72, borderRadius: 20),
                    SizedBox(height: 8),
                    ShimmerBox(height: 72, borderRadius: 20),
                  ],
                ),
                error: (e, _) => ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(payoutsProvider),
                ),
                data: (rows) => Column(
                  children: [
                    if (rows.isEmpty)
                      const EmptyState(
                        message: 'No payouts yet.',
                        icon: Icons.payments_outlined,
                      ),
                    for (final row in rows)
                      SleekCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.payments_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row['amount']} · ${row['method']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    '${row['created_at'] ?? ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(status: '${row['status']}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
