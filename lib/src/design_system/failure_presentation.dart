import 'package:flutter/material.dart';

import '../localization/foundation_strings.dart';
import '../network/network.dart';
import 'app_state_widgets.dart';

/// User-facing presentation of an error: never raw exception text.
final class FailurePresentation {
  const FailurePresentation({
    required this.state,
    required this.title,
    required this.message,
    required this.retryable,
  });

  /// Maps [error] to safe, localized copy. [ApiFailure] messages follow the
  /// wire contract ("safe user-facing summary") and are shown as-is; any other
  /// error type gets a generic message so internals never leak to users.
  factory FailurePresentation.from(Object error, FoundationStrings strings) {
    if (error is ApiFailure) {
      return switch (error.kind) {
        ApiFailureKind.offline || ApiFailureKind.timeout => FailurePresentation(
          state: FoundationViewState.offline,
          title: strings.offlineTitle,
          message: strings.offlineMessage,
          retryable: true,
        ),
        ApiFailureKind.unauthorized => FailurePresentation(
          state: FoundationViewState.error,
          title: strings.sessionExpiredTitle,
          message: strings.sessionExpiredMessage,
          retryable: false,
        ),
        ApiFailureKind.upgradeRequired => FailurePresentation(
          state: FoundationViewState.error,
          title: strings.updateRequiredTitle,
          message: strings.updateRequiredMessage,
          retryable: false,
        ),
        _ => FailurePresentation(
          state: FoundationViewState.error,
          title: strings.genericErrorTitle,
          message: error.message,
          retryable: error.retryable || error.kind == ApiFailureKind.server,
        ),
      };
    }
    return FailurePresentation(
      state: FoundationViewState.error,
      title: strings.genericErrorTitle,
      message: strings.genericErrorMessage,
      retryable: true,
    );
  }

  final FoundationViewState state;
  final String title;
  final String message;
  final bool retryable;
}

/// Shows a snack bar, replacing any visible one. No-op without a
/// [ScaffoldMessenger] ancestor.
void showFoundationSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}
