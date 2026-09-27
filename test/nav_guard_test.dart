// DDE-Mart driver app — safePush guard tests (original).
//
// Shell-branch destinations must never duplicate the shell match
// (`!keyReservation.contains(key)` red screens).

// ignore_for_file: avoid_print

import 'package:dde_driver/core/nav.dart';
import 'package:dde_driver/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shell flows never duplicate page keys', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            return MaterialApp.router(
                routerConfig: r.watch(routerProvider));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    BuildContext ctx() => tester.element(find.byType(Scaffold).first);

    Future<void> go(String location) async {
      ctx().safePush(location);
      await tester.pumpAndSettle();
    }

    await go('/jobs');
    await go('/payouts');
    await go('/documents');
    await go('/chat');
    await go('/sos');
    await go('/profile');
    await go('/jobs');
    await go('/payouts');
  });
}
