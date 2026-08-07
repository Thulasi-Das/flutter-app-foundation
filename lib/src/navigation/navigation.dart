enum RouteAccess { allow, redirectToSignIn, redirectToUpgrade, deny }

final class AppDestination<T extends Object?> {
  const AppDestination({
    required this.name,
    required this.path,
    this.requiresAuthentication = false,
    this.restorable = true,
  });

  final String name;
  final String path;
  final bool requiresAuthentication;
  final bool restorable;
}

final class NavigationIntent<T extends Object?> {
  const NavigationIntent(this.destination, {this.arguments});
  final AppDestination<T> destination;
  final T? arguments;
}

abstract interface class RouteGuard {
  Future<RouteAccess> evaluate(NavigationIntent<Object?> intent);
}

abstract interface class NavigationDriver {
  Future<void> go<T extends Object?>(NavigationIntent<T> intent);
  Future<bool> maybePop();
  String? get currentLocation;
}

abstract interface class UnsavedChangesGuard {
  Future<bool> mayLeave(String currentLocation);
}

final class GuardedNavigationDriver implements NavigationDriver {
  const GuardedNavigationDriver({
    required this.delegate,
    required this.routeGuards,
    required this.unsavedChanges,
    required this.onDenied,
  });

  final NavigationDriver delegate;
  final List<RouteGuard> routeGuards;
  final UnsavedChangesGuard unsavedChanges;
  final Future<void> Function(RouteAccess access) onDenied;

  @override
  String? get currentLocation => delegate.currentLocation;

  @override
  Future<void> go<T extends Object?>(NavigationIntent<T> intent) async {
    final current = delegate.currentLocation;
    if (current != null && !await unsavedChanges.mayLeave(current)) return;
    for (final guard in routeGuards) {
      final access = await guard.evaluate(
        NavigationIntent<Object?>(
          AppDestination<Object?>(
            name: intent.destination.name,
            path: intent.destination.path,
            requiresAuthentication: intent.destination.requiresAuthentication,
            restorable: intent.destination.restorable,
          ),
          arguments: intent.arguments,
        ),
      );
      if (access != RouteAccess.allow) {
        await onDenied(access);
        return;
      }
    }
    await delegate.go(intent);
  }

  @override
  Future<bool> maybePop() => delegate.maybePop();
}
