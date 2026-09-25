import 'package:flutter/widgets.dart';

/// Makes one explicitly constructed service available to a widget subtree.
///
/// This is constructor injection for widgets, not a service locator: every
/// service is created at the composition root and passed in by type.
///
/// ```dart
/// ServiceScope<TodoRepository>(service: repository, child: const TodoPage());
/// // later
/// final repository = context.service<TodoRepository>();
/// ```
final class ServiceScope<T extends Object> extends InheritedWidget {
  const ServiceScope({required this.service, required super.child, super.key});

  final T service;

  /// Finds the nearest [T]. With [listen] the caller rebuilds when the scope
  /// provides a different instance.
  static T of<T extends Object>(BuildContext context, {bool listen = false}) {
    final value = maybeOf<T>(context, listen: listen);
    if (value == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No ServiceScope<$T> found.'),
        ErrorHint(
          'Wrap the app in ServiceScope<$T>, MultiServiceScope, or pass it '
          'through FoundationApp(services: [...]).',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return value;
  }

  static T? maybeOf<T extends Object>(
    BuildContext context, {
    bool listen = false,
  }) => listen
      ? context.dependOnInheritedWidgetOfExactType<ServiceScope<T>>()?.service
      : context.getInheritedWidgetOfExactType<ServiceScope<T>>()?.service;

  @override
  bool updateShouldNotify(ServiceScope<T> oldWidget) =>
      !identical(service, oldWidget.service);
}

/// A typed service registration for [MultiServiceScope].
final class ServiceBinding<T extends Object> {
  const ServiceBinding(this.service);

  final T service;

  Widget wrap(Widget child) => ServiceScope<T>(service: service, child: child);
}

/// Provides several services without deep nesting.
final class MultiServiceScope extends StatelessWidget {
  const MultiServiceScope({
    required this.services,
    required this.child,
    super.key,
  });

  final List<ServiceBinding<Object>> services;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      services.reversed.fold(child, (inner, binding) => binding.wrap(inner));
}

extension ServiceScopeContext on BuildContext {
  /// Reads a service provided by [ServiceScope] without subscribing.
  T service<T extends Object>() => ServiceScope.of<T>(this);
}
