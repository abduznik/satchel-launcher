import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activity_provider.dart';

/// Bottom-right status panel. Slides in while a task runs, shows a green
/// checkmark when done, then slides back out.
class ActivityPanel extends ConsumerStatefulWidget {
  const ActivityPanel({super.key});

  @override
  ConsumerState<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends ConsumerState<ActivityPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handle(ActivityState? prev, ActivityState? next) {
    _hideTimer?.cancel();

    if (next == null) {
      // Task cleared → slide back out
      if (_controller.value > 0 && !_controller.isAnimating) {
        _controller.reverse();
      }
      return;
    }

    if (prev == null || next.nonce != prev.nonce) {
      // New or updated task → slide in and show progress
      if (!_controller.isAnimating && _controller.value < 1) {
        _controller.forward();
      }
    }

    // Done → hold with green checkmark for 2.5s, then slide back out
    if (next.status == ActivityStatus.done ||
        next.status == ActivityStatus.error) {
      _hideTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        ref.read(activityProvider.notifier).hide();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider);
    ref.listen<ActivityState?>(activityProvider, _handle);

    if (activity == null) {
      if (_controller.value > 0 && !_controller.isAnimating) {
        _controller.reverse();
      }
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return SlideTransition(
      position: _slide,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusIcon(status: activity.status),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.message,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (activity.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      activity.detail!,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final ActivityStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ActivityStatus.running:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ActivityStatus.done:
        return const Icon(Icons.check_circle,
            size: 18, color: Color(0xFF22C55E));
      case ActivityStatus.error:
        return const Icon(Icons.error_outline,
            size: 18, color: Color(0xFFEF4444));
    }
  }
}
