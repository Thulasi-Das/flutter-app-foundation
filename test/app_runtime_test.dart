import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_app_foundation/flutter_app_foundation_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoundationApp', () {
    testWidgets('gates routes behind bootstrap with localized strings', (
      tester,
    ) async {
      final step = Completer<void>();
      final bootstrap = BootstrapCoordinator(<StartupStep>[
        StartupStep(id: 'config', run: () => step.future),
      ]);
      var homeBuilt = false;
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          strings: const FoundationStrings(startingTitle: 'Démarrage'),
          bootstrap: bootstrap,
          services: const <ServiceBinding<Object>>[
            ServiceBinding<String>('service'),
          ],
          home: Builder(
            builder: (context) {
              homeBuilt = true;
              return Text(context.service<String>());
            },
          ),
        ),
      );
      expect(find.text('Démarrage'), findsOneWidget);
      expect(homeBuilt, isFalse);

      step.complete();
      await tester.pumpAndSettle();
      expect(find.text('service'), findsOneWidget);
      await bootstrap.dispose();
    });

    testWidgets('shows a recoverable failure and retries', (tester) async {
      var attempts = 0;
      final bootstrap = BootstrapCoordinator(<StartupStep>[
        StartupStep(
          id: 'flaky',
          run: () async {
            if (++attempts == 1) throw StateError('first run fails');
          },
        ),
      ]);
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          bootstrap: bootstrap,
          home: const Text('home'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(FoundationStrings.english.startupFailedTitle),
        findsOneWidget,
      );
      expect(find.textContaining('flaky'), findsNothing);

      await tester.tap(find.text(FoundationStrings.english.retry));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      await bootstrap.dispose();
    });

    testWidgets('blocks the app when an update is required', (tester) async {
      var requested = false;
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          updateRequired: true,
          onUpdateRequested: () => requested = true,
          home: const Text('home'),
        ),
      );
      expect(find.text('home'), findsNothing);
      await tester.tap(find.text(FoundationStrings.english.update));
      expect(requested, isTrue);
    });

    testWidgets('follows and persists the theme controller', (tester) async {
      final store = InMemoryKeyValueStore(<String, String>{
        'foundation.theme_mode': 'dark',
      });
      final controller = ThemeController(store: store);
      await controller.load();
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          themeController: controller,
          home: const Scaffold(),
        ),
      );
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.highContrastTheme, isNotNull);

      await controller.setMode(ThemeMode.light);
      await tester.pump();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      expect(await store.read('foundation.theme_mode'), 'light');
    });
  });

  group('FoundationRouteTable', () {
    const home = AppDestination<Object?>(name: 'home', path: '/');
    const task = AppDestination<Object?>(
      name: 'task',
      path: '/projects/:projectId/tasks/:taskId',
      requiresAuthentication: true,
    );
    const signIn = AppDestination<Object?>(name: 'signIn', path: '/sign-in');

    FoundationRouteTable table({required bool signedIn}) =>
        FoundationRouteTable(
          isAuthenticated: () => signedIn,
          signInPath: '/sign-in',
          routes: <FoundationRoute>[
            FoundationRoute(
              destination: home,
              builder: (context, _) => const Text('home'),
            ),
            FoundationRoute(
              destination: task,
              builder: (context, match) => Text(
                'task ${match.pathParameters['projectId']}/'
                '${match.pathParameters['taskId']} '
                '${match.queryParameters['tab']}',
              ),
            ),
            FoundationRoute(
              destination: signIn,
              builder: (context, match) =>
                  Text('sign in → ${match.queryParameters['redirect']}'),
            ),
          ],
        );

    testWidgets('extracts path and query parameters', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          navigatorKey: key,
          initialRoute: '/projects/p%201/tasks/42?tab=notes',
          routeTable: table(signedIn: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('task p 1/42 notes'), findsOneWidget);

      // A deep-linked launch stacks exactly root + target.
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(key.currentState!.canPop(), isFalse);
    });

    testWidgets('redirects protected routes to sign-in', (tester) async {
      final routes = table(signedIn: false);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          navigatorKey: key,
          onGenerateRoute: routes.onGenerateRoute,
        ),
      );
      unawaited(key.currentState!.pushNamed('/projects/a/tasks/b'));
      await tester.pumpAndSettle();
      expect(find.text('sign in → /projects/a/tasks/b'), findsOneWidget);
    });

    testWidgets('shows a not-found page with back navigation', (tester) async {
      final routes = table(signedIn: true);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          navigatorKey: key,
          onGenerateRoute: routes.onGenerateRoute,
        ),
      );
      unawaited(key.currentState!.pushNamed('/missing'));
      await tester.pumpAndSettle();
      expect(
        find.text(FoundationStrings.english.pageNotFoundTitle),
        findsOneWidget,
      );
      await tester.tap(find.text(FoundationStrings.english.goBack));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    test('rejects duplicate paths', () {
      expect(
        () => FoundationRouteTable(
          routes: <FoundationRoute>[
            FoundationRoute(
              destination: home,
              builder: (_, _) => const Text('a'),
            ),
            FoundationRoute(
              destination: home,
              builder: (_, _) => const Text('b'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    testWidgets('navigator driver works with guards and tracks location', (
      tester,
    ) async {
      final routes = table(signedIn: true);
      final key = GlobalKey<NavigatorState>();
      final driver = NavigatorNavigationDriver(key);
      final denied = <RouteAccess>[];
      var signedIn = false;
      final guarded = GuardedNavigationDriver(
        delegate: driver,
        routeGuards: <RouteGuard>[AuthenticationRouteGuard(() => signedIn)],
        unsavedChanges: const AlwaysAllowUnsavedChangesGuard(),
        onDenied: (access) async => denied.add(access),
      );
      await tester.pumpWidget(
        FoundationApp(
          title: 'Test',
          navigatorKey: key,
          navigatorObservers: <NavigatorObserver>[driver.observer],
          onGenerateRoute: routes.onGenerateRoute,
        ),
      );
      const intent = NavigationIntent<Object?>(
        AppDestination<Object?>(
          name: 'task',
          path: '/projects/1/tasks/2',
          requiresAuthentication: true,
        ),
      );
      await guarded.go(intent);
      expect(denied, <RouteAccess>[RouteAccess.redirectToSignIn]);

      signedIn = true;
      unawaited(guarded.go(intent));
      await tester.pumpAndSettle();
      expect(driver.currentLocation, '/projects/1/tasks/2');
      expect(await driver.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(driver.currentLocation, '/');
    });
  });

  group('Validators', () {
    test('compose returns the first failure', () {
      final validator = FoundationValidators.compose(
        <FormFieldValidator<String>>[
          FoundationValidators.required(),
          FoundationValidators.email(),
        ],
      );
      expect(validator(''), 'This field is required.');
      expect(validator('nope'), 'Enter a valid email address.');
      expect(validator(' person@example.com '), isNull);
    });

    test('length, number, pattern, and match rules', () {
      expect(FoundationValidators.minLength(8)('short'), isNotNull);
      expect(FoundationValidators.maxLength(3)('long'), isNotNull);
      expect(FoundationValidators.number(min: 1, max: 5)('9'), isNotNull);
      expect(FoundationValidators.number()('x'), 'Enter a valid number.');
      expect(FoundationValidators.number(min: 1)('3'), isNull);
      expect(
        FoundationValidators.pattern(RegExp(r'^\d+$'), message: 'digits')('a'),
        'digits',
      );
      expect(FoundationValidators.matches(() => 'a')('b'), isNotNull);
    });
  });

  testWidgets('async button prevents double submit and reports failures', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      FoundationTestHarness(
        child: FoundationAsyncButton(
          label: 'Save',
          onPressed: () {
            calls++;
            return pending.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.completeError(ApiFailure.offline(correlationId: 'c'));
    await tester.pumpAndSettle();
    expect(find.text(FoundationStrings.english.offlineMessage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('installed error handlers forward framework errors', (
    tester,
  ) async {
    final reporter = _RecordingReporter();
    final restore = installFoundationErrorHandlers(reporter);
    final previousPresent = FlutterError.presentError;
    FlutterError.presentError = (_) {};
    try {
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('x'), library: 'widgets'),
      );
    } finally {
      FlutterError.presentError = previousPresent;
      restore();
    }
    expect(reporter.errors.single, (false, 'widgets'));
  });
}

final class _RecordingReporter implements CrashReporter {
  final List<(bool, String?)> errors = <(bool, String?)>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? source,
  }) async => errors.add((fatal, source));
}
