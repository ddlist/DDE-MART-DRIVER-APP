// DDE-Mart driver app — entry point (original, clean-room rebuild).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push.dart';
import 'core/theme.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: DdeDriverApp()));
}

class DdeDriverApp extends ConsumerWidget {
  const DdeDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Instantiates the session watcher; syncs push once per sign-in.
    ref.watch(pushSyncProvider);

    return MaterialApp.router(
      title: 'DDE Driver',
      debugShowCheckedModeBanner: false,
      theme: DdeTheme.light(),
      darkTheme: DdeTheme.dark(),
      routerConfig: router,
    );
  }
}
