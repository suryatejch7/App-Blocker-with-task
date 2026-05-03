import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _OverlayToastItem {
  final String id;
  final OverlayEntry entry;
  final Timer timer;

  _OverlayToastItem({
    required this.id,
    required this.entry,
    required this.timer,
  });
}

class ToastService {
  static final List<_OverlayToastItem> _activeToasts = [];

  static void dispose() {
    for (final toast in _activeToasts) {
      toast.entry.remove();
      toast.timer.cancel();
    }
    _activeToasts.clear();
  }

  static void _repositionToasts() {
    for (final toast in _activeToasts) {
      toast.entry.markNeedsBuild();
    }
  }

  static void showToast(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);

    final toastId = DateTime.now().microsecondsSinceEpoch.toString();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        final index = _activeToasts.indexWhere((t) => t.id == toastId);
        final safeTop = MediaQuery.of(overlayContext).padding.top;
        final y = safeTop + 12 + ((index < 0 ? 0 : index) * 40.0);

        return Positioned(
          top: y,
          right: 12,
          child: IgnorePointer(
            child: _PillToast(
              message: message,
              backgroundColor: backgroundColor ?? AppTheme.blue,
            ),
          ),
        );
      },
    );

    final timer = Timer(duration, () {
      final i = _activeToasts.indexWhere((t) => t.id == toastId);
      if (i >= 0) {
        _activeToasts[i].entry.remove();
        _activeToasts.removeAt(i);
        _repositionToasts();
      }
    });

    _activeToasts.add(
      _OverlayToastItem(id: toastId, entry: entry, timer: timer),
    );
    overlay.insert(entry);
    _repositionToasts();
  }
}

class _PillToast extends StatelessWidget {
  final String message;
  final Color backgroundColor;

  const _PillToast({required this.message, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
