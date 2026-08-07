import 'package:flutter/material.dart';

import 'design_tokens.dart';

enum FoundationViewState { loading, empty, error, offline }

final class FoundationStateView extends StatelessWidget {
  const FoundationStateView({
    required this.state,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final FoundationViewState state;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      FoundationViewState.loading => Icons.hourglass_top,
      FoundationViewState.empty => Icons.inbox_outlined,
      FoundationViewState.error => Icons.error_outline,
      FoundationViewState.offline => Icons.cloud_off_outlined,
    };
    return Semantics(
      container: true,
      liveRegion: state == FoundationViewState.error,
      label: '$title. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(FoundationSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (state == FoundationViewState.loading)
                  const CircularProgressIndicator()
                else
                  Icon(icon, size: 40),
                const SizedBox(height: FoundationSpacing.md),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: FoundationSpacing.xs),
                Text(message, textAlign: TextAlign.center),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: FoundationSpacing.md),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class FoundationStatusBanner extends StatelessWidget {
  const FoundationStatusBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: <Widget>[
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ]),
          ),
        ),
      );
}
