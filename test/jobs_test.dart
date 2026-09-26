// DDE-Mart driver app — job-move + gate unit tests (original).

import 'package:dde_driver/core/gate.dart';
import 'package:dde_driver/features/jobs/jobs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gateStatus', () {
    test('maintenance wins', () {
      expect(
        gateStatus(current: '9.9.9', minimum: '1.0.0', maintenance: true),
        GateDecision.maintenance,
      );
    });

    test('older app requires update, equal passes', () {
      expect(
        gateStatus(current: '1.0.0', minimum: '2.0.0', maintenance: false),
        GateDecision.updateRequired,
      );
      expect(
        gateStatus(current: '2.0.0', minimum: '2.0.0', maintenance: false),
        GateDecision.ok,
      );
    });
  });

  group('nextMove', () {
    DriverJob job(String status) => DriverJob(
          type: 'ride',
          id: 1,
          number: 'CAB-1',
          status: status,
          total: 100,
        );

    test('pool jobs accept', () {
      expect(nextMove(job('placed'), owned: false), 'accepted');
    });

    test('owned jobs advance, terminal jobs rest', () {
      expect(nextMove(job('accepted'), owned: true), 'ongoing');
      expect(nextMove(job('ongoing'), owned: true), 'completed');
      expect(nextMove(job('completed'), owned: true), isNull);
      expect(nextMove(job('cancelled'), owned: true), isNull);
    });
  });
}
