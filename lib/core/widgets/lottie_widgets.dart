import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// ─── Reusable loading indicator ──────────────────────────────────────────────

class LottieLoading extends StatelessWidget {
  final double size;
  const LottieLoading({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) => Lottie.asset(
        'assets/animations/loading.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
}

// ─── Overlay helpers ──────────────────────────────────────────────────────────

/// Plays Check.lottie once then auto-dismisses.
Future<void> showSuccessOverlay(BuildContext context, {String? message}) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _AnimOverlay(
        path: 'assets/animations/check.json',
        autoClose: true,
        message: message,
      ),
    );

/// Plays error animation once, shows [message], tap backdrop to dismiss.
Future<void> showErrorOverlay(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => _AnimOverlay(
        path: 'assets/animations/error.json',
        message: message,
        autoClose: false,
      ),
    );

// ─── Internal dialog widget ───────────────────────────────────────────────────

class _AnimOverlay extends StatefulWidget {
  final String path;
  final String? message;
  final bool autoClose;
  const _AnimOverlay({required this.path, this.message, required this.autoClose});

  @override
  State<_AnimOverlay> createState() => _AnimOverlayState();
}

class _AnimOverlayState extends State<_AnimOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.autoClose ? null : () => Navigator.pop(context),
      child: Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              widget.path,
              controller: _ctrl,
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              onLoaded: (c) {
                _ctrl.duration = c.duration;
                _ctrl.forward().whenComplete(() {
                  if (widget.autoClose && mounted) Navigator.pop(context);
                });
              },
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 8),
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
