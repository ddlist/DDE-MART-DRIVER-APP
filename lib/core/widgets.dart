// DDE-Mart driver app — shared display widgets.
//
// Status pills and empty states plus the sleek component kit shared by
// every screen: gradient headers, stat cards, soft-shadow cards, shimmer
// loading, timelines, fare rows, story strips and the floating bottom bar.

import 'package:flutter/material.dart';

import 'media_api.dart';
import 'theme.dart';

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
        borderRadius: BorderRadius.circular(DdeTheme.radiusPill),
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: DdeTheme.iconTile(context, radius: 22),
              child: const Icon(
                Icons.inbox_outlined,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Builder(builder: (context) {
              // Keep the requested icon visible alongside the brand tile
              // when callers pass a specific one.
              return icon == Icons.inbox_outlined
                  ? const SizedBox.shrink()
                  : Icon(icon, size: 28, color: scheme.outline);
            }),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard error + retry state.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              error.toString().replaceFirst('ApiException(null): ', ''),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Gradient hero header with rounded bottom, icon tile, title + subtitle.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.local_shipping_outlined,
    this.trailing,
    this.accent = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final decoration = (accent
            ? DdeTheme.accentGradient(context)
            : DdeTheme.headerGradient(context))
        .copyWith(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(DdeTheme.radiusSheet),
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: decoration,
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

/// Sleek card with soft layered shadow (never flat grey elevation).
class SleekCard extends StatelessWidget {
  const SleekCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.radius = DdeTheme.radiusCardLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: DdeTheme.softShadow(context),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: card,
    );
  }
}

/// Stat card: gradient icon tile + bold value + muted label.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent = false,
    this.success = false,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool accent;
  final bool success;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: SleekCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: DdeTheme.iconTile(
                context,
                accent: accent,
                success: success,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(fontSize: 22),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading box (no new packages): animated gradient sweep.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 12,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Vertical timeline dots with connectors (job history / progress).
class TimelineDots extends StatelessWidget {
  const TimelineDots({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            last: i == steps.length - 1,
          ),
      ],
    );
  }
}

class TimelineStep {
  TimelineStep({required this.label, this.detail, this.done = true});

  final String label;
  final String? detail;
  final bool done;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.last,
  });

  final TimelineStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = step.done;
    final dotColor = active ? DdeTheme.success : scheme.outline;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? dotColor : Colors.transparent,
                  border: Border.all(color: dotColor, width: 2.5),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: (active
                              ? DdeTheme.success
                              : scheme.outlineVariant)
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (step.detail != null && step.detail!.isNotEmpty)
                    Text(
                      step.detail!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single fare-breakdown row.
class BillRow extends StatelessWidget {
  const BillRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.icon,
  });

  final String label;
  final String value;
  final bool bold;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: scheme.primary)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: bold
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Text(value, style: style?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Compact horizontal stories strip for the Jobs tab.
class StoryStrip extends StatelessWidget {
  const StoryStrip({super.key, required this.stories});

  final List<DriverStory> stories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (stories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DdeTheme.accent,
                      Theme.of(context).colorScheme.primary,
                    ],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerLow,
                  ),
                  child: ClipOval(
                    child: story.thumbnail != null &&
                            story.thumbnail!.isNotEmpty
                        ? Image.network(
                            story.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.play_circle_outline,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.play_circle_outline,
                            size: 28,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 66,
                child: Text(
                  story.storeName ?? 'Story',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Floating custom bottom bar: rounded 24, margin 12, selected pill.
class DdeBottomBar extends StatelessWidget {
  const DdeBottomBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<DdeBarItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DdeTheme.radiusCardLg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: DdeTheme.softShadow(context),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              _BarButton(
                item: items[i],
                selected: i == index,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class DdeBarItem {
  DdeBarItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DdeBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(DdeTheme.radiusPill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DdeTheme.radiusPill),
          gradient: selected
              ? LinearGradient(
                  colors: [scheme.primary, DdeTheme.primaryDark],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
