import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_app_foundation/flutter_app_foundation_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsyncController', () {
    test('keeps only the latest result of overlapping runs', () async {
      final controller = AsyncController<String>();
      final slow = Completer<String>();
      final first = controller.run(() => slow.future);
      final second = controller.run(() async => 'fresh');
      await second;
      slow.complete('stale');
      await first;
      expect(controller.value, const AsyncData<String>('fresh'));
    });

    test('keeps the previous value while loading and after errors', () async {
      final errors = <Object>[];
      final controller = AsyncController<int>(onError: (e, _) => errors.add(e));
      await controller.run(() async => 1);
      final pending = Completer<int>();
      final run = controller.run(() => pending.future);
      expect(controller.value.isLoading, isTrue);
      expect(controller.value.valueOrNull, 1);
      pending.completeError(StateError('boom'));
      await run;
      expect(controller.value.hasError, isTrue);
      expect(controller.value.valueOrNull, 1);
      expect(errors.single, isA<StateError>());
    });

    test('ignores results that arrive after dispose', () async {
      final controller = AsyncController<int>();
      final pending = Completer<int>();
      final run = controller.run(() => pending.future);
      controller.dispose();
      pending.complete(1);
      await run;
      expect(controller.isDisposed, isTrue);
    });

    test('refresh requires a load function', () {
      expect(AsyncController<int>().refresh, throwsStateError);
    });
  });

  group('AsyncValueBuilder', () {
    testWidgets('renders loading, data, and empty states', (tester) async {
      final pending = Completer<List<String>>();
      final controller = AsyncController<List<String>>(
        load: () => pending.future,
      );
      unawaited(controller.refresh());
      await tester.pumpWidget(
        FoundationTestHarness(
          child: AsyncValueBuilder<List<String>>(
            controller: controller,
            isEmpty: (items) => items.isEmpty,
            builder: (context, items) => Text(items.join(',')),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(<String>['a', 'b']);
      await tester.pump();
      expect(find.text('a,b'), findsOneWidget);

      controller.set(<String>[]);
      await tester.pump();
      expect(find.text(FoundationStrings.english.emptyTitle), findsOneWidget);
      controller.dispose();
    });

    testWidgets('offline failures show offline copy with retry', (
      tester,
    ) async {
      var calls = 0;
      final controller = AsyncController<String>(
        load: () async {
          calls++;
          if (calls == 1) throw ApiFailure.offline(correlationId: 'c');
          return 'loaded';
        },
      );
      await tester.pumpWidget(
        FoundationTestHarness(
          child: AsyncValueBuilder<String>(
            controller: controller,
            builder: (context, value) => Text(value),
          ),
        ),
      );
      await tester.runAsync(controller.refresh);
      await tester.pump();
      expect(find.text(FoundationStrings.english.offlineTitle), findsOneWidget);

      await tester.tap(find.text(FoundationStrings.english.retry));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('loaded'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('unknown errors never leak their message', (tester) async {
      final controller = AsyncController<String>(
        initial: AsyncError<String>(StateError('secret internal detail')),
      );
      await tester.pumpWidget(
        FoundationTestHarness(
          child: AsyncValueBuilder<String>(
            controller: controller,
            builder: (context, value) => Text(value),
          ),
        ),
      );
      expect(find.textContaining('secret'), findsNothing);
      expect(
        find.text(FoundationStrings.english.genericErrorMessage),
        findsOneWidget,
      );
      controller.dispose();
    });
  });

  group('ServiceScope', () {
    testWidgets('provides services by type', (tester) async {
      late String value;
      late int number;
      await tester.pumpWidget(
        MultiServiceScope(
          services: const <ServiceBinding<Object>>[
            ServiceBinding<String>('hello'),
            ServiceBinding<int>(7),
          ],
          child: Builder(
            builder: (context) {
              value = context.service<String>();
              number = ServiceScope.of<int>(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(value, 'hello');
      expect(number, 7);
    });

    testWidgets('explains a missing scope', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            context.service<double>();
            return const SizedBox();
          },
        ),
      );
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('No ServiceScope<double> found'),
        ),
      );
    });
  });
}
