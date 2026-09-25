import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

final class Todo {
  const Todo({required this.id, required this.title, required this.done});

  factory Todo.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return Todo(
      id: '${map['id']}',
      title: map['title']! as String,
      done: map['completed'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final bool done;

  Todo copyWith({bool? done}) =>
      Todo(id: id, title: title, done: done ?? this.done);
}

/// Feature code depends on this interface, never on HTTP or storage details.
abstract interface class TodoRepository {
  Future<List<Todo>> list();
  Future<Todo> get(String id);
  Future<Todo> setDone(String id, {required bool done});
}

final class HttpTodoRepository implements TodoRepository {
  const HttpTodoRepository(this._client);

  final NetworkClient _client;

  @override
  Future<List<Todo>> list() => _client.getJson(
    'todos',
    query: const <String, String>{'_limit': '20'},
    decode: (json) =>
        (json! as List<Object?>).map(Todo.fromJson).toList(growable: false),
  );

  @override
  Future<Todo> get(String id) => _client.getJson(
    'todos/${Uri.encodeComponent(id)}',
    decode: Todo.fromJson,
  );

  @override
  Future<Todo> setDone(String id, {required bool done}) => _client.patchJson(
    'todos/${Uri.encodeComponent(id)}',
    body: <String, Object?>{'completed': done},
    decode: Todo.fromJson,
  );
}

/// In-memory data with simulated latency so the example runs offline.
final class DemoTodoRepository implements TodoRepository {
  final Map<String, Todo> _todos = <String, Todo>{
    for (final (index, title) in <String>[
      'Read the integration guide',
      'Wire a real CrashReporter',
      'Replace demo data with HttpTodoRepository',
      'Ship it',
    ].indexed)
      '${index + 1}': Todo(id: '${index + 1}', title: title, done: index == 0),
  };

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  @override
  Future<List<Todo>> list() async {
    await _latency();
    return _todos.values.toList(growable: false);
  }

  @override
  Future<Todo> get(String id) async {
    await _latency();
    return _todos[id] ??
        (throw const ApiFailure(
          kind: ApiFailureKind.notFound,
          code: 'todo_not_found',
          message: 'This todo no longer exists.',
          correlationId: 'demo',
          retryable: false,
          statusCode: 404,
        ));
  }

  @override
  Future<Todo> setDone(String id, {required bool done}) async {
    final updated = (await get(id)).copyWith(done: done);
    return _todos[id] = updated;
  }
}
