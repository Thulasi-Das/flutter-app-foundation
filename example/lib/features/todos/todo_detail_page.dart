import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

import 'todo_repository.dart';

final class TodoDetailPage extends StatefulWidget {
  const TodoDetailPage({required this.id, super.key});

  final String id;

  @override
  State<TodoDetailPage> createState() => _TodoDetailPageState();
}

final class _TodoDetailPageState extends State<TodoDetailPage> {
  late final TodoRepository _repository = context.service<TodoRepository>();
  late final AsyncController<Todo> _todo = AsyncController(
    load: () => _repository.get(widget.id),
  );

  @override
  void initState() {
    super.initState();
    _todo.refresh();
  }

  @override
  void dispose() {
    _todo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Todo')),
    body: AsyncValueBuilder<Todo>(
      controller: _todo,
      builder: (context, todo) => ListView(
        padding: const EdgeInsets.all(FoundationSpacing.lg),
        children: <Widget>[
          Text(todo.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: FoundationSpacing.md),
          FoundationAsyncButton(
            label: todo.done ? 'Mark as not done' : 'Mark as done',
            icon: todo.done ? Icons.undo : Icons.check,
            expand: true,
            onPressed: () async =>
                _todo.set(await _repository.setDone(todo.id, done: !todo.done)),
          ),
        ],
      ),
    ),
  );
}
