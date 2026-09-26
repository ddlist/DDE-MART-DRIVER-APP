// DDE-Mart driver app — smoke test (original).

import 'package:dde_driver/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to driver sign-in offline', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DdeDriverApp()));
    await tester.pumpAndSettle();

    expect(find.text('Driver sign in'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
