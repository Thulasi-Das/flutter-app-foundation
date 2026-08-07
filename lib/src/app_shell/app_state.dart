enum GlobalAppState {
  ready,
  offline,
  sessionExpired,
  migrationFailed,
  updateRequired,
  maintenance,
}

final class AppStateNotice {
  const AppStateNotice({
    required this.state,
    required this.title,
    required this.message,
    this.actionLabel,
  });

  final GlobalAppState state;
  final String title;
  final String message;
  final String? actionLabel;
}
