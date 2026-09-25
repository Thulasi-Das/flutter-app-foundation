import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/app_state_widgets.dart';
import '../localization/foundation_strings.dart';
import 'bootstrap.dart';

/// Shows startup progress and a recoverable failure screen until the
/// [BootstrapCoordinator] is ready, then builds [child].
final class BootstrapGate extends StatefulWidget {
  const BootstrapGate({
    required this.coordinator,
    required this.child,
    this.loadingBuilder,
    this.failureBuilder,
    super.key,
  });

  final BootstrapCoordinator coordinator;
  final Widget child;

  /// Replaces the default loading view, e.g. with a branded splash.
  final Widget Function(BuildContext context, BootstrapSnapshot snapshot)?
  loadingBuilder;

  /// Replaces the default failure view. Call `retry` to restart startup.
  final Widget Function(
    BuildContext context,
    BootstrapFailure failure,
    VoidCallback retry,
  )?
  failureBuilder;

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

final class _BootstrapGateState extends State<BootstrapGate> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.coordinator.start());
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<BootstrapSnapshot>(
    stream: widget.coordinator.snapshots,
    initialData: widget.coordinator.snapshot,
    builder: (context, asyncSnapshot) {
      final snapshot = asyncSnapshot.data!;
      if (snapshot.phase == BootstrapPhase.ready) return widget.child;
      final strings = FoundationStrings.of(context);
      void retry() => unawaited(widget.coordinator.retry());
      final failure = snapshot.failure;
      final content = snapshot.phase == BootstrapPhase.failed && failure != null
          ? widget.failureBuilder?.call(context, failure, retry) ??
                FoundationStateView(
                  state: FoundationViewState.error,
                  title: strings.startupFailedTitle,
                  message: strings.startupFailedMessage,
                  actionLabel: strings.retry,
                  onAction: retry,
                )
          : widget.loadingBuilder?.call(context, snapshot) ??
                FoundationStateView(
                  state: FoundationViewState.loading,
                  title: strings.startingTitle,
                  message: strings.startingMessage,
                );
      // The gate may sit above the Navigator (FoundationApp.builder), so it
      // supplies its own Material surface.
      return Material(child: SafeArea(child: content));
    },
  );
}
