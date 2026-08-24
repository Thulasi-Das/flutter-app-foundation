import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

void main() => runApp(const FoundationExample());

final class FoundationExample extends StatefulWidget {
  const FoundationExample({super.key});

  @override
  State<FoundationExample> createState() => _FoundationExampleState();
}

final class _FoundationExampleState extends State<FoundationExample> {
  late final BootstrapCoordinator bootstrap;
  var themeMode = ThemeMode.system;
  var selectedIndex = 0;
  var intensity = 3.0;
  var notifications = true;

  @override
  void initState() {
    super.initState();
    bootstrap = BootstrapCoordinator(<StartupStep>[
      StartupStep(id: 'configuration', run: () async {}),
      StartupStep(id: 'local database', run: () async {}),
      StartupStep(id: 'session', run: () async {}),
    ]);
  }

  @override
  void dispose() {
    unawaited(bootstrap.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Foundation example',
        debugShowCheckedModeBanner: false,
        theme: FoundationTheme.light(),
        darkTheme: FoundationTheme.dark(),
        themeMode: themeMode,
        home: BootstrapGate(
          coordinator: bootstrap,
          child: AdaptiveAppShell(
            destinations: const <FoundationDestination>[
              FoundationDestination(
                label: 'Components',
                icon: Icons.widgets_outlined,
                selectedIcon: Icons.widgets,
              ),
              FoundationDestination(
                label: 'States',
                icon: Icons.cloud_outlined,
                selectedIcon: Icons.cloud,
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: (value) =>
                setState(() => selectedIndex = value),
            appBar: AppBar(
              title: const Text('Flutter App Foundation'),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Toggle theme',
                  onPressed: () => setState(() {
                    themeMode = themeMode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  }),
                  icon: const Icon(Icons.contrast),
                ),
              ],
            ),
            notice: selectedIndex == 1
                ? const AppStateNotice(
                    state: GlobalAppState.offline,
                    title: 'Offline',
                    message: 'Changes remain on this device until sync resumes.',
                    actionLabel: 'Retry',
                  )
                : null,
            onNoticeAction: () {},
            body: selectedIndex == 0
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: <Widget>[
                      Text('Accessible fields',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      const FoundationTextField(
                        label: 'Email',
                        helperText: 'Labels and helper text are always explicit.',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: <String>[AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      const FoundationPasswordField(label: 'Password'),
                      const SizedBox(height: 16),
                      FoundationSlider(
                        label: 'Accountability intensity',
                        value: intensity,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        valueLabel: intensity.round().toString(),
                        onChanged: (value) => setState(() => intensity = value),
                      ),
                      FoundationCheckbox(
                        label: 'Allow reminders',
                        subtitle: 'The product decides when to request permission.',
                        value: notifications,
                        onChanged: (value) =>
                            setState(() => notifications = value),
                      ),
                    ],
                  )
                : const FoundationStateView(
                    state: FoundationViewState.offline,
                    title: 'You are offline',
                    message:
                        'Local work continues. Sync will retry when a request succeeds.',
                  ),
          ),
        ),
      );
}
