import 'dart:async';

enum NotificationPermission { unknown, notRequested, denied, provisional, granted }

final class NotificationEnvelope {
  const NotificationEnvelope({
    required this.eventId,
    required this.eventType,
    this.deepLink,
  });

  final String eventId;
  final String eventType;
  final Uri? deepLink;
}

final class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.id,
    required this.category,
    required this.fireAt,
    required this.titleKey,
    required this.bodyKey,
    this.payload = const <String, String>{},
  });

  final String id;
  final String category;
  final DateTime fireAt;
  final String titleKey;
  final String bodyKey;
  final Map<String, String> payload;
}

abstract interface class NotificationService {
  Future<NotificationPermission> permission();
  Future<NotificationPermission> requestPermission();
  Future<String?> deviceToken();
  Stream<String> get tokenRotations;
  Stream<NotificationEnvelope> get openedNotifications;
  Future<void> schedule(LocalNotificationRequest request);
  Future<void> cancel(String id);
  Future<void> cancelAll();
}

final class InMemoryNotificationService implements NotificationService {
  NotificationPermission permissionValue = NotificationPermission.notRequested;
  String? token;
  final List<LocalNotificationRequest> scheduled = <LocalNotificationRequest>[];
  final StreamController<String> _tokenRotations =
      StreamController<String>.broadcast(sync: true);
  final StreamController<NotificationEnvelope> _opened =
      StreamController<NotificationEnvelope>.broadcast(sync: true);

  @override
  Future<NotificationPermission> permission() async => permissionValue;
  @override
  Future<NotificationPermission> requestPermission() async => permissionValue;
  @override
  Future<String?> deviceToken() async => token;
  @override
  Stream<String> get tokenRotations => _tokenRotations.stream;
  @override
  Stream<NotificationEnvelope> get openedNotifications => _opened.stream;

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    scheduled.removeWhere((item) => item.id == request.id);
    scheduled.add(request);
  }

  @override
  Future<void> cancel(String id) async =>
      scheduled.removeWhere((item) => item.id == id);
  @override
  Future<void> cancelAll() async => scheduled.clear();

  void rotateToken(String value) {
    token = value;
    _tokenRotations.add(value);
  }

  void open(NotificationEnvelope value) => _opened.add(value);

  Future<void> dispose() async {
    await _tokenRotations.close();
    await _opened.close();
  }
}
