import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current status message shown in the overlay.
final statusMessageProvider = StateProvider<StatusMessage?>((ref) => null);

class StatusMessage {
  final String message;
  final String? detail;
  final StatusType type;
  final DateTime timestamp;

  StatusMessage({
    required this.message,
    this.detail,
    this.type = StatusType.info,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum StatusType { info, success, warning, error }

/// Bottom-right status overlay that shows background task progress.
class StatusOverlay extends ConsumerStatefulWidget {
  const StatusOverlay({super.key});

  @override
  ConsumerState<StatusOverlay> createState() => _StatusOverlayState();
}

class _StatusOverlayState extends ConsumerState<StatusOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(statusMessageProvider);

    if (status == null) {
      if (_controller.isAnimating || _controller.isCompleted) {
        _controller.reverse();
      }
      return const SizedBox.shrink();
    }

    // Show and auto-hide after 4 seconds
    if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
      _autoHideTimer?.cancel();
      _autoHideTimer = Timer(const Duration(seconds: 4), () {
        ref.read(statusMessageProvider.notifier).state = null;
      });
    }

    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _getBgColor(context, status.type),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _getBorderColor(context, status.type),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(status.type),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.message,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (status.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      status.detail!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ref.read(statusMessageProvider.notifier).state = null;
                _controller.reverse();
              },
              child: Icon(
                Icons.close,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(StatusType type) {
    switch (type) {
      case StatusType.info:
        return const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case StatusType.success:
        return const Icon(Icons.check_circle, size: 16, color: Color(0xFF22C55E));
      case StatusType.warning:
        return const Icon(Icons.warning_amber, size: 16, color: Color(0xFFF59E0B));
      case StatusType.error:
        return const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444));
    }
  }

  Color _getBgColor(BuildContext context, StatusType type) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case StatusType.info:
        return cs.surface;
      case StatusType.success:
        return const Color(0xFF052E16);
      case StatusType.warning:
        return const Color(0xFF422006);
      case StatusType.error:
        return const Color(0xFF450A0A);
    }
  }

  Color _getBorderColor(BuildContext context, StatusType type) {
    switch (type) {
      case StatusType.info:
        return Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
      case StatusType.success:
        return const Color(0xFF16A34A).withValues(alpha: 0.3);
      case StatusType.warning:
        return const Color(0xFFF59E0B).withValues(alpha: 0.3);
      case StatusType.error:
        return const Color(0xFFEF4444).withValues(alpha: 0.3);
    }
  }
}

/// Helper to show a status message from anywhere in the app.
void showStatus(WidgetRef ref, String message, {String? detail, StatusType type = StatusType.info}) {
  ref.read(statusMessageProvider.notifier).state = StatusMessage(
    message: message,
    detail: detail,
    type: type,
  );
}

void showStatusSuccess(WidgetRef ref, String message, {String? detail}) {
  showStatus(ref, message, detail: detail, type: StatusType.success);
}

void showStatusError(WidgetRef ref, String message, {String? detail}) {
  showStatus(ref, message, detail: detail, type: StatusType.error);
}

void hideStatus(WidgetRef ref) {
  ref.read(statusMessageProvider.notifier).state = null;
}
