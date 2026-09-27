// DDE-Mart driver app — shared display widgets (original).
//
// Status pills and empty states shared by jobs, payouts, documents and
// chat so every screen looks like one app.

import 'package:flutter/material.dart';

/// Colored status pill.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  static Color colorFor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'pending':
        return Colors.amber.shade700;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
      case 'ongoing':
        return Colors.purple;
      case 'completed':
      case 'paid':
      case 'approved':
      case 'verified':
      case 'online':
      case 'active':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Standard empty state so screens never render blank.
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
