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
    DriverJob job(String type, String status) => DriverJob(
          type: type,
          id: 1,
          number: 'JOB-1',
          status: status,
          total: 100,
        );

    test('pool jobs accept', () {
      expect(nextMove(job('ride', 'placed'), owned: false), 'accepted');
    });

    test('food and parcel ship, then complete', () {
      expect(nextMove(job('food', 'accepted'), owned: true), 'shipped');
      expect(nextMove(job('parcel', 'accepted'), owned: true), 'shipped');
      expect(nextMove(job('food', 'shipped'), owned: true), 'completed');
      expect(nextMove(job('parcel', 'shipped'), owned: true), 'completed');
    });

    test('rental and rides go ongoing, then complete', () {
      expect(nextMove(job('rental', 'accepted'), owned: true), 'ongoing');
      expect(nextMove(job('ride', 'accepted'), owned: true), 'ongoing');
      expect(nextMove(job('rental', 'ongoing'), owned: true), 'completed');
      expect(nextMove(job('ride', 'ongoing'), owned: true), 'completed');
    });

    test('terminal jobs rest', () {
      expect(nextMove(job('food', 'completed'), owned: true), isNull);
      expect(nextMove(job('ride', 'cancelled'), owned: true), isNull);
    });
  });
}
