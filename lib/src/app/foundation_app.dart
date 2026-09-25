import 'package:flutter/material.dart';

import '../bootstrap/bootstrap.dart';
import '../bootstrap/bootstrap_gate.dart';
import '../design_system/app_state_widgets.dart';
import '../design_system/foundation_theme.dart';
import '../localization/foundation_strings.dart';
import '../navigation/route_table.dart';
import '../state/service_scope.dart';
import 'theme_controller.dart';

/// The application root: theming (light, dark, high contrast), framework
/// strings, service scopes, startup gating, and an optional forced-update
/// gate around a standard [MaterialApp].
///
/// Use [home]/[onGenerateRoute] for Navigator-based apps, or [routerConfig]
/// for a `Router` package such as go_router.
final class FoundationApp extends StatelessWidget {
  const FoundationApp({
    required this.title,
    this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.routeTable,
    this.routerConfig,
    this.bootstrap,
    this.bootstrapLoadingBuilder,
    this.themeController,
    this.seedColor,
    this.theme,
    this.darkTheme,
    this.strings = FoundationStrings.english,
    this.services = const <ServiceBinding<Object>>[],
    this.navigatorKey,
    this.scaffoldMessengerKey,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.locale,
    this.supportedLocales = const <Locale>[Locale('en')],
    this.localizationsDelegates,
    this.builder,
    this.updateRequired = false,
    this.onUpdateRequested,
    this.debugShowCheckedModeBanner = false,
    super.key,
  }) : assert(
         routerConfig == null ||
             (home == null && onGenerateRoute == null && routeTable == null),
         'Use either routerConfig or home/onGenerateRoute/routeTable.',
       ),
       assert(
         routeTable == null ||
             (onGenerateRoute == null && onUnknownRoute == null),
         'routeTable supplies onGenerateRoute and onUnknownRoute.',
       );

  final String title;
  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final String? initialRoute;
  final RouteFactory? onGenerateRoute;
  final RouteFactory? onUnknownRoute;

  /// Declarative routes; supplies route generation, deep-link initial
  /// routes, and the not-found page.
  final FoundationRouteTable? routeTable;
  final RouterConfig<Object>? routerConfig;

  /// Startup steps that must complete before any route is built.
  final BootstrapCoordinator? bootstrap;
  final Widget Function(BuildContext context, BootstrapSnapshot snapshot)?
  bootstrapLoadingBuilder;

  final ThemeController? themeController;

  /// Brand color used to derive the color scheme when [theme] is not given.
  final Color? seedColor;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final FoundationStrings strings;

  /// Services made available to every route through [ServiceScope].
  final List<ServiceBinding<Object>> services;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final List<NavigatorObserver> navigatorObservers;
  final Locale? locale;
  final Iterable<Locale> supportedLocales;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final TransitionBuilder? builder;

  /// When true, a blocking update screen replaces the app, e.g. from
  /// `AppConfiguration.requiresUpdate`.
  final bool updateRequired;
  final VoidCallback? onUpdateRequested;
  final bool debugShowCheckedModeBanner;

  @override
  Widget build(BuildContext context) {
    final controller = themeController;
    return controller == null
        ? _buildApp(ThemeMode.system)
        : ListenableBuilder(
            listenable: controller,
            builder: (context, _) => _buildApp(controller.mode),
          );
  }

  Widget _buildApp(ThemeMode mode) {
    final light = theme ?? FoundationTheme.light(seedColor: seedColor);
    final dark = darkTheme ?? FoundationTheme.dark(seedColor: seedColor);
    final highContrastLight =
        theme ??
        FoundationTheme.light(seedColor: seedColor, highContrast: true);
    final highContrastDark =
        darkTheme ??
        FoundationTheme.dark(seedColor: seedColor, highContrast: true);

    Widget wrap(BuildContext context, Widget? child) {
      Widget current = child ?? const SizedBox.shrink();
      if (builder != null) current = builder!(context, current);
      final coordinator = bootstrap;
      if (coordinator != null) {
        current = BootstrapGate(
          coordinator: coordinator,
          loadingBuilder: bootstrapLoadingBuilder,
          child: current,
        );
      }
      if (updateRequired) {
        current = Material(
          child: SafeArea(
            child: FoundationStateView(
              state: FoundationViewState.error,
              title: strings.updateRequiredTitle,
              message: strings.updateRequiredMessage,
              actionLabel: onUpdateRequested == null ? null : strings.update,
              onAction: onUpdateRequested,
            ),
          ),
        );
      }
      return FoundationStringsScope(
        strings: strings,
        child: MultiServiceScope(services: services, child: current),
      );
    }

    final router = routerConfig;
    if (router != null) {
      return MaterialApp.router(
        title: title,
        routerConfig: router,
        theme: light,
        darkTheme: dark,
        highContrastTheme: highContrastLight,
        highContrastDarkTheme: highContrastDark,
        themeMode: mode,
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        scaffoldMessengerKey: scaffoldMessengerKey,
        builder: wrap,
        debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      );
    }
    return MaterialApp(
      title: title,
      home: home,
      routes: routes,
      initialRoute: initialRoute,
      onGenerateRoute: routeTable?.onGenerateRoute ?? onGenerateRoute,
      onUnknownRoute: routeTable?.onUnknownRoute ?? onUnknownRoute,
      onGenerateInitialRoutes: routeTable?.onGenerateInitialRoutes,
      navigatorKey: navigatorKey,
      navigatorObservers: navigatorObservers,
      theme: light,
      darkTheme: dark,
      highContrastTheme: highContrastLight,
      highContrastDarkTheme: highContrastDark,
      themeMode: mode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationsDelegates,
      scaffoldMessengerKey: scaffoldMessengerKey,
      builder: wrap,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }
}
