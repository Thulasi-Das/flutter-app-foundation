import 'package:flutter/material.dart';

import '../localization/foundation_strings.dart';
import 'failure_presentation.dart';

enum FoundationButtonVariant { filled, tonal, outlined, text }

/// A button for asynchronous actions (submit, save, sign in).
///
/// It disables itself and shows progress while [onPressed] runs, which
/// prevents double submission. Failures go to [onError], or by default to a
/// snack bar with safe, localized copy.
final class FoundationAsyncButton extends StatefulWidget {
  const FoundationAsyncButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = FoundationButtonVariant.filled,
    this.onError,
    this.expand = false,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final FoundationButtonVariant variant;
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Stretch to the available width (typical for form submit buttons).
  final bool expand;

  @override
  State<FoundationAsyncButton> createState() => _FoundationAsyncButtonState();
}

final class _FoundationAsyncButtonState extends State<FoundationAsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    final action = widget.onPressed;
    if (action == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error, stackTrace) {
      if (!mounted) return;
      final onError = widget.onError;
      if (onError != null) {
        onError(error, stackTrace);
      } else {
        final strings = FoundationStrings.of(context);
        showFoundationSnackBar(
          context,
          FailurePresentation.from(error, strings).message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_busy;
    final onPressed = enabled ? _run : null;
    final label = Text(widget.label);
    final Widget? icon = _busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : widget.icon == null
        ? null
        : Icon(widget.icon);
    final button = switch (widget.variant) {
      FoundationButtonVariant.filled =>
        icon == null
            ? FilledButton(onPressed: onPressed, child: label)
            : FilledButton.icon(onPressed: onPressed, icon: icon, label: label),
      FoundationButtonVariant.tonal =>
        icon == null
            ? FilledButton.tonal(onPressed: onPressed, child: label)
            : FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: icon,
                label: label,
              ),
      FoundationButtonVariant.outlined =>
        icon == null
            ? OutlinedButton(onPressed: onPressed, child: label)
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: icon,
                label: label,
              ),
      FoundationButtonVariant.text =>
        icon == null
            ? TextButton(onPressed: onPressed, child: label)
            : TextButton.icon(onPressed: onPressed, icon: icon, label: label),
    };
    return Semantics(
      value: _busy ? FoundationStrings.of(context).loading : null,
      child: widget.expand
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
