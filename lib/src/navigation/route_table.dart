import 'package:flutter/material.dart';

import '../design_system/app_state_widgets.dart';
import '../localization/foundation_strings.dart';
import 'navigation.dart';

/// The parsed result of matching a location against a route pattern.
final class FoundationRouteMatch {
  const FoundationRouteMatch({
    required this.location,
    required this.pathParameters,
    required this.queryParameters,
    this.arguments,
  });

  final Uri location;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;
  final Object? arguments;
}

/// A screen bound to an [AppDestination]. The destination path may contain
/// parameters such as `/projects/:projectId/tasks/:taskId`.
final class FoundationRoute {
  const FoundationRoute({
    required this.destination,
    required this.builder,
    this.fullscreenDialog = false,
  });

  final AppDestination<Object?> destination;
  final Widget Function(BuildContext context, FoundationRouteMatch match)
  builder;
  final bool fullscreenDialog;

  List<String> get _segments => _split(destination.path);

  FoundationRouteMatch? match(Uri location, Object? arguments) {
    final pattern = _segments;
    final actual = _split(location.path);
    if (pattern.length != actual.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      final segment = pattern[i];
      if (segment.startsWith(':')) {
        params[segment.substring(1)] = Uri.decodeComponent(actual[i]);
      } else if (segment != actual[i]) {
        return null;
      }
    }
    return FoundationRouteMatch(
      location: location,
      pathParameters: Map<String, String>.unmodifiable(params),
      queryParameters: location.queryParameters,
      arguments: arguments,
    );
  }

  static List<String> _split(String path) =>
      path.split('/').where((segment) => segment.isNotEmpty).toList();
}

/// Declarative route table for `Navigator`-based apps with path parameters,
/// query parameters, an authentication redirect, and a not-found page.
///
/// ```dart
/// final table = FoundationRouteTable(
///   routes: [FoundationRoute(destination: home, builder: (_, _) => const Home())],
///   isAuthenticated: () => auth.snapshot.status == AuthStatus.authenticated,
///   signInPath: '/sign-in',
/// );
/// FoundationApp(onGenerateRoute: table.onGenerateRoute, ...);
/// ```
final class FoundationRouteTable {
  FoundationRouteTable({
    required List<FoundationRoute> routes,
    this.isAuthenticated,
    this.signInPath,
    this.notFoundBuilder,
  }) : routes = List<FoundationRoute>.unmodifiable(routes) {
    final paths = <String>{};
    for (final route in routes) {
      if (!paths.add(route.destination.path)) {
        throw ArgumentError.value(
          route.destination.path,
          'routes',
          'Duplicate route path.',
        );
      }
    }
    if (isAuthenticated != null && signInPath == null) {
      throw ArgumentError('signInPath is required with isAuthenticated.');
    }
  }

  final List<FoundationRoute> routes;
  final bool Function()? isAuthenticated;

  /// Receives the original location as the `redirect` query parameter.
  final String? signInPath;
  final WidgetBuilder? notFoundBuilder;

  /// Returns the matching route and its parameters, or null.
  (FoundationRoute, FoundationRouteMatch)? resolve(
    String location, {
    Object? arguments,
  }) {
    final uri = Uri.parse(location);
    for (final route in routes) {
      final match = route.match(uri, arguments);
      if (match != null) return (route, match);
    }
    return null;
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '/';
    final resolved = resolve(name, arguments: settings.arguments);
    if (resolved == null) return onUnknownRoute(settings);
    final (route, match) = resolved;
    final authenticated = isAuthenticated;
    if (route.destination.requiresAuthentication &&
        authenticated != null &&
        !authenticated()) {
      final signIn = Uri.parse(
        signInPath!,
      ).replace(queryParameters: <String, String>{'redirect': name});
      final signInRoute = resolve(signIn.toString());
      if (signInRoute != null) {
        return MaterialPageRoute<Object?>(
          settings: RouteSettings(name: signIn.toString()),
          builder: (context) => signInRoute.$1.builder(context, signInRoute.$2),
        );
      }
    }
    return MaterialPageRoute<Object?>(
      settings: settings,
      fullscreenDialog: route.fullscreenDialog,
      builder: (context) => route.builder(context, match),
    );
  }

  Route<dynamic> onUnknownRoute(RouteSettings settings) =>
      MaterialPageRoute<Object?>(
        settings: settings,
        builder: notFoundBuilder ?? (context) => const _NotFoundPage(),
      );
}

final class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    final strings = FoundationStrings.of(context);
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: FoundationStateView(
        state: FoundationViewState.empty,
        title: strings.pageNotFoundTitle,
        message: strings.pageNotFoundMessage,
        actionLabel: navigator.canPop() ? strings.goBack : null,
        onAction: navigator.canPop() ? navigator.pop : null,
      ),
    );
  }
}

/// A [NavigationDriver] backed by a `Navigator`, for use with
/// [GuardedNavigationDriver] and [FoundationRouteTable].
///
/// Add [observer] to the app's navigator observers so [currentLocation]
/// tracks back navigation too.
final class NavigatorNavigationDriver implements NavigationDriver {
  NavigatorNavigationDriver(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;
  late final NavigatorObserver observer = _LocationObserver(this);
  String? _location;

  @override
  String? get currentLocation => _location;

  NavigatorState get _navigator {
    final state = navigatorKey.currentState;
    if (state == null) {
      throw StateError('The navigator is not mounted yet.');
    }
    return state;
  }

  /// Pushes the destination's path. Paths containing parameters should be
  /// passed already filled in (see [AppDestination.path]).
  @override
  Future<void> go<T extends Object?>(NavigationIntent<T> intent) async {
    await _navigator.pushNamed<Object?>(
      intent.destination.path,
      arguments: intent.arguments,
    );
  }

  /// Replaces the whole stack, e.g. after sign-in or sign-out.
  Future<void> replaceAll(String path, {Object? arguments}) async {
    await _navigator.pushNamedAndRemoveUntil<Object?>(
      path,
      (_) => false,
      arguments: arguments,
    );
  }

  @override
  Future<bool> maybePop() async =>
      await navigatorKey.currentState?.maybePop() ?? false;
}

final class _LocationObserver extends NavigatorObserver {
  _LocationObserver(this._driver);

  final NavigatorNavigationDriver _driver;

  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) _driver._location = name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);
}
