// DDE-Mart driver app — onboarding + help pages.
//
// Onboarding slides from GET /onboarding?audience=driver (skipped when
// none configured); public CMS pages viewer for terms/privacy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

final driverOnboardingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/onboarding', queryParameters: {
    'audience': 'driver',
  });
  return (((response.data as Map)['data'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() =>
      _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState
    extends ConsumerState<DriverOnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding.done', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final slides = ref.watch(driverOnboardingProvider);

    return Scaffold(
      body: SafeArea(
        child: slides.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerBox(width: 200, height: 120, borderRadius: 24),
                SizedBox(height: 16),
                ShimmerBox(width: 240, height: 20, borderRadius: 10),
                SizedBox(height: 8),
                ShimmerBox(width: 180, height: 14, borderRadius: 8),
              ],
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apiMessage(e)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _finish, child: const Text('Skip')),
              ],
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              Future.microtask(_finish);
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: rows.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) {
                      final slide = rows[index];
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 160,
                              height: 160,
                              decoration: DdeTheme.headerGradient(
                                context,
                              ).copyWith(
                                borderRadius: BorderRadius.circular(48),
                                boxShadow:
                                    DdeTheme.softShadow(context),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                size: 84,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),
                            SleekCard(
                              child: Column(
                                children: [
                                  Text(
                                    '${slide['title'] ?? ''}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${slide['description'] ?? ''}',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 220),
                        width: _page == i ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: _page == i
                              ? LinearGradient(
                                  colors: [
                                    DdeTheme.accent,
                                    Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ],
                                )
                              : null,
                          color: _page == i
                              ? null
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      TextButton(
                          onPressed: _finish,
                          child: const Text('Skip')),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          if (_page == rows.length - 1) {
                            _finish();
                          } else {
                            _controller.nextPage(
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        child: Text(
                          _page == rows.length - 1
                              ? 'Get started'
                              : 'Next',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DriverPagesScreen extends ConsumerWidget {
  const DriverPagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & policies')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: () async {
          final dio = ref.watch(dioProvider);
          final response = await dio.get('/pages');
          return (((response.data as Map)['data'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ShimmerBox(height: 64, borderRadius: 20),
                SizedBox(height: 8),
                ShimmerBox(height: 64, borderRadius: 20),
                SizedBox(height: 8),
                ShimmerBox(height: 64, borderRadius: 20),
              ],
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              error: snapshot.error!,
              onRetry: () => (context as Element).markNeedsBuild(),
            );
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const EmptyState(
              message: 'Nothing here.',
              icon: Icons.help_outline,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                SleekCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.zero,
                  onTap: () =>
                      context.safePush('/page/${row['slug']}'),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: DdeTheme.iconTile(context),
                      child: const Icon(
                        Icons.article_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text('${row['name']}'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DriverPageDetailScreen extends ConsumerWidget {
  const DriverPageDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: () async {
          final dio = ref.watch(dioProvider);
          final response = await dio.get('/pages/$slug');
          return Map<String, dynamic>.from(
            (response.data as Map)['data'] as Map,
          );
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                ShimmerBox(width: 200, height: 28, borderRadius: 8),
                SizedBox(height: 12),
                ShimmerBox(height: 14, borderRadius: 8),
                SizedBox(height: 8),
                ShimmerBox(height: 14, borderRadius: 8),
                SizedBox(height: 8),
                ShimmerBox(height: 14, borderRadius: 8),
              ],
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              error: snapshot.error!,
              onRetry: () => (context as Element).markNeedsBuild(),
            );
          }
          final page = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SleekCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${page['name'] ?? ''}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text('${page['body'] ?? ''}'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
