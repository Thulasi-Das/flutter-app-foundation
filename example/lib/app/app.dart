import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

import '../features/components/components_page.dart';
import '../features/settings/settings_page.dart';
import '../features/todos/todo_detail_page.dart';
import '../features/todos/todo_repository.dart';
import '../features/todos/todos_page.dart';
import 'services.dart';

abstract final class Destinations {
  static const home = AppDestination<Object?>(name: 'home', path: '/');
  static const todo = AppDestination<Object?>(name: 'todo', path: '/todos/:id');
}

final class ExampleApp extends StatelessWidget {
  ExampleApp({required this.services, super.key});

  final AppServices services;

  late final FoundationRouteTable _routes = FoundationRouteTable(
    routes: <FoundationRoute>[
      FoundationRoute(
        destination: Destinations.home,
        builder: (context, _) => const HomeShell(),
      ),
      FoundationRoute(
        destination: Destinations.todo,
        builder: (context, match) =>
            TodoDetailPage(id: match.pathParameters['id']!),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => FoundationApp(
    title: 'Foundation example',
    seedColor: const Color(0xFF3157D5),
    themeController: services.theme,
    bootstrap: services.bootstrap,
    routeTable: _routes,
    services: <ServiceBinding<Object>>[
      ServiceBinding<TodoRepository>(services.todos),
      ServiceBinding<ThemeController>(services.theme),
    ],
  );
}

final class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  static const _pages = <Widget>[TodosPage(), ComponentsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) => AdaptiveAppShell(
    appBar: AppBar(title: const Text('Flutter App Foundation')),
    selectedIndex: _index,
    onDestinationSelected: (index) => setState(() => _index = index),
    destinations: const <FoundationDestination>[
      FoundationDestination(
        label: 'Todos',
        icon: Icons.checklist_outlined,
        selectedIcon: Icons.checklist,
      ),
      FoundationDestination(
        label: 'Components',
        icon: Icons.widgets_outlined,
        selectedIcon: Icons.widgets,
      ),
      FoundationDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ],
    body: _pages[_index],
  );
}
