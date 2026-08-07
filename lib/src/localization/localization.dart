abstract interface class MessageCatalog {
  String message(String key, {Map<String, Object> arguments = const {}});
}

abstract interface class LocaleController {
  String get localeTag;
  bool get isRightToLeft;
  Future<void> setLocale(String localeTag);
}

final class MapMessageCatalog implements MessageCatalog {
  const MapMessageCatalog(this.messages);
  final Map<String, String> messages;

  @override
  String message(String key, {Map<String, Object> arguments = const {}}) {
    var result = messages[key] ?? key;
    for (final entry in arguments.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }
}
