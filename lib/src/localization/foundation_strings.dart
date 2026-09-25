import 'package:flutter/widgets.dart';

/// User-visible text rendered by foundation widgets.
///
/// English defaults are provided; supply a translated instance through
/// `FoundationApp(strings: ...)` or [FoundationStringsScope] — for example by
/// building one from the app's generated `AppLocalizations`.
final class FoundationStrings {
  const FoundationStrings({
    this.startingTitle = 'Starting',
    this.startingMessage = 'Preparing the app.',
    this.startupFailedTitle = 'Could not start the app',
    this.startupFailedMessage =
        'Something went wrong while starting. Please try again.',
    this.retry = 'Try again',
    this.cancel = 'Cancel',
    this.confirm = 'Continue',
    this.dismiss = 'Dismiss',
    this.goBack = 'Go back',
    this.loading = 'Loading',
    this.showPassword = 'Show password',
    this.hidePassword = 'Hide password',
    this.clearSearch = 'Clear search',
    this.genericErrorTitle = 'Something went wrong',
    this.genericErrorMessage = 'Please try again.',
    this.offlineTitle = 'You are offline',
    this.offlineMessage = 'Check your connection and try again.',
    this.sessionExpiredTitle = 'Session expired',
    this.sessionExpiredMessage = 'Sign in again to continue.',
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'Items you add will appear here.',
    this.pageNotFoundTitle = 'Page not found',
    this.pageNotFoundMessage = 'This page does not exist or has moved.',
    this.updateRequiredTitle = 'Update required',
    this.updateRequiredMessage =
        'This version is no longer supported. Update to continue.',
    this.update = 'Update',
    this.fatalErrorTitle = 'Something went wrong',
    this.fatalErrorMessage = 'Restart the app to continue.',
  });

  final String startingTitle;
  final String startingMessage;
  final String startupFailedTitle;
  final String startupFailedMessage;
  final String retry;
  final String cancel;
  final String confirm;
  final String dismiss;
  final String goBack;
  final String loading;
  final String showPassword;
  final String hidePassword;
  final String clearSearch;
  final String genericErrorTitle;
  final String genericErrorMessage;
  final String offlineTitle;
  final String offlineMessage;
  final String sessionExpiredTitle;
  final String sessionExpiredMessage;
  final String emptyTitle;
  final String emptyMessage;
  final String pageNotFoundTitle;
  final String pageNotFoundMessage;
  final String updateRequiredTitle;
  final String updateRequiredMessage;
  final String update;
  final String fatalErrorTitle;
  final String fatalErrorMessage;

  static const FoundationStrings english = FoundationStrings();

  /// The nearest scoped strings, or English defaults.
  static FoundationStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FoundationStringsScope>()
          ?.strings ??
      english;
}

final class FoundationStringsScope extends InheritedWidget {
  const FoundationStringsScope({
    required this.strings,
    required super.child,
    super.key,
  });

  final FoundationStrings strings;

  @override
  bool updateShouldNotify(FoundationStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
