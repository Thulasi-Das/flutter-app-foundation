import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

import 'todo_repository.dart';

final class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

final class _TodosPageState extends State<TodosPage> {
  late final TodoRepository _repository = context.service<TodoRepository>();
  late final AsyncController<List<Todo>> _todos = AsyncController(
    load: _repository.list,
  );

  @override
  void initState() {
    super.initState();
    _todos.refresh();
  }

  @override
  void dispose() {
    _todos.dispose();
    super.dispose();
  }

  Future<void> _toggle(Todo todo, bool done) async {
    final current = _todos.value.valueOrNull ?? const <Todo>[];
    // Optimistic update; the async error path restores truth by reloading.
    _todos.set([
      for (final item in current)
        item.id == todo.id ? item.copyWith(done: done) : item,
    ]);
    try {
      await _repository.setDone(todo.id, done: done);
    } on Object {
      await _todos.refresh();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => AsyncValueBuilder<List<Todo>>(
    controller: _todos,
    isEmpty: (todos) => todos.isEmpty,
    builder: (context, todos) => RefreshIndicator(
      onRefresh: _todos.refresh,
      child: ListView.separated(
        itemCount: todos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final todo = todos[index];
          return CheckboxListTile(
            value: todo.done,
            title: Text(todo.title),
            secondary: IconButton(
              tooltip: 'Open ${todo.title}',
              icon: const Icon(Icons.chevron_right),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/todos/${todo.id}'),
            ),
            onChanged: (value) =>
                _toggle(todo, value ?? false).catchError((Object error) {
                  if (!context.mounted) return;
                  showFoundationSnackBar(
                    context,
                    FailurePresentation.from(
                      error,
                      FoundationStrings.of(context),
                    ).message,
                  );
                }),
          );
        },
      ),
    ),
  );
}
