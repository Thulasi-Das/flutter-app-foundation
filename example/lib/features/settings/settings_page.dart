import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

final class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.service<ThemeController>();
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(FoundationSpacing.lg),
        children: <Widget>[
          FoundationSegmented<ThemeMode>(
            label: 'Theme',
            options: ThemeMode.values,
            optionLabel: (mode) => switch (mode) {
              ThemeMode.system => 'System',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            },
            selected: <ThemeMode>{theme.mode},
            onChanged: (modes) => theme.setMode(modes.single),
          ),
        ],
      ),
    );
  }
}
