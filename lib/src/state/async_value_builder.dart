import 'package:flutter/material.dart';

import '../design_system/app_state_widgets.dart';
import '../design_system/failure_presentation.dart';
import '../localization/foundation_strings.dart';
import 'async_controller.dart';
import 'async_value.dart';

/// Renders an [AsyncController] with accessible default loading, empty, and
/// error states, so screens only describe the data case.
///
/// When a refresh fails but a previous value exists, the data stays visible
/// and the error is surfaced in a banner instead of replacing the screen.
final class AsyncValueBuilder<T> extends StatelessWidget {
  const AsyncValueBuilder({
    required this.controller,
    required this.builder,
    this.isEmpty,
    this.emptyTitle,
    this.emptyMessage,
    this.loadingBuilder,
    this.errorBuilder,
    this.onRetry,
    super.key,
  });

  final AsyncController<T> controller;
  final Widget Function(BuildContext context, T value) builder;

  /// When it returns true for loaded data, the empty state is shown.
  final bool Function(T value)? isEmpty;
  final String? emptyTitle;
  final String? emptyMessage;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Defaults to [AsyncController.refresh].
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AsyncValue<T>>(
    valueListenable: controller,
    builder: (context, value, _) {
      final strings = FoundationStrings.of(context);
      final retry = onRetry ?? controller.refresh;
      if (value.hasValue) {
        final data = value.valueOrNull as T;
        final content = isEmpty?.call(data) ?? false
            ? FoundationStateView(
                state: FoundationViewState.empty,
                title: emptyTitle ?? strings.emptyTitle,
                message: emptyMessage ?? strings.emptyMessage,
              )
            : builder(context, data);
        final error = value.errorOrNull;
        return Column(
          children: <Widget>[
            if (value.isLoading) const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              FoundationStatusBanner(
                message: FailurePresentation.from(error, strings).message,
                icon: Icons.error_outline,
                actionLabel: strings.retry,
                onAction: retry,
              ),
            Expanded(child: content),
          ],
        );
      }
      return switch (value) {
        AsyncError<T>(:final error) =>
          errorBuilder?.call(context, error) ??
              _ErrorView(error: error, strings: strings, onRetry: retry),
        _ =>
          loadingBuilder?.call(context) ??
              FoundationStateView(
                state: FoundationViewState.loading,
                title: strings.loading,
                message: '',
              ),
      };
    },
  );
}

final class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.strings,
    required this.onRetry,
  });

  final Object error;
  final FoundationStrings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final presentation = FailurePresentation.from(error, strings);
    return FoundationStateView(
      state: presentation.state,
      title: presentation.title,
      message: presentation.message,
      actionLabel: presentation.retryable ? strings.retry : null,
      onAction: presentation.retryable ? onRetry : null,
    );
  }
}
