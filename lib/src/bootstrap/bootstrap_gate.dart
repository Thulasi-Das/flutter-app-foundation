import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/app_state_widgets.dart';
import 'bootstrap.dart';

final class BootstrapGate extends StatefulWidget {
  const BootstrapGate({
    required this.coordinator,
    required this.child,
    super.key,
  });

  final BootstrapCoordinator coordinator;
  final Widget child;

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
      return switch (snapshot.phase) {
        BootstrapPhase.ready => widget.child,
        BootstrapPhase.failed => FoundationStateView(
          state: FoundationViewState.error,
          title: 'Could not start the app',
          message: 'Startup step ${snapshot.failure?.stepId} failed.',
          actionLabel: 'Try again',
          onAction: () => unawaited(widget.coordinator.retry()),
        ),
        BootstrapPhase.idle || BootstrapPhase.running => FoundationStateView(
          state: FoundationViewState.loading,
          title: 'Starting',
          message: snapshot.activeStepId == null
              ? 'Preparing the app.'
              : 'Preparing ${snapshot.activeStepId}.',
        ),
      };
    },
  );
}
