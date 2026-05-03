import 'dart:async';

import 'package:flutter/material.dart';

class OverlayToastService {
  final List<_OverlayToastItem> _activeToasts = [];

  void dispose() {
    for (final toast in _activeToasts) {
      toast.entry.remove();
      toast.timer.cancel();
    }
    _activeToasts.clear();
  }

  void showTopRightToast({
    required BuildContext context,
    required Widget child,
    Duration duration = const Duration(seconds: 3),
    double topPadding = 12,
    double rightPadding = 12,
    double verticalSpacing = 40,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final toastId = DateTime.now().microsecondsSinceEpoch.toString();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        final index = _activeToasts.indexWhere((t) => t.id == toastId);
        final safeTop = MediaQuery.of(overlayContext).padding.top;
        final y = safeTop + topPadding + ((index < 0 ? 0 : index) * verticalSpacing);

        return Positioned(
          top: y,
          right: rightPadding,
          child: IgnorePointer(child: child),
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

    _activeToasts.add(_OverlayToastItem(id: toastId, entry: entry, timer: timer));
    overlay.insert(entry);
    _repositionToasts();
  }

  void _repositionToasts() {
    for (final toast in _activeToasts) {
      toast.entry.markNeedsBuild();
    }
  }
}

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
