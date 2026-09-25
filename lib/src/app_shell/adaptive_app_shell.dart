import 'package:flutter/material.dart';

import '../design_system/app_state_widgets.dart';
import 'app_state.dart';

final class FoundationDestination {
  const FoundationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

final class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.notice,
    this.onNoticeAction,
    this.appBar,
    this.desktopBreakpoint = 720,
    super.key,
  });

  final List<FoundationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final AppStateNotice? notice;
  final VoidCallback? onNoticeAction;
  final PreferredSizeWidget? appBar;
  final double desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    assert(destinations.isNotEmpty);
    assert(selectedIndex >= 0 && selectedIndex < destinations.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= desktopBreakpoint;
        final content = Column(
          children: <Widget>[
            if (notice != null)
              FoundationStatusBanner(
                message: '${notice!.title}: ${notice!.message}',
                actionLabel: notice!.actionLabel,
                onAction: onNoticeAction,
                icon: _noticeIcon(notice!.state),
              ),
            Expanded(child: body),
          ],
        );
        return Scaffold(
          appBar: appBar,
          body: wide
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                      )
                      .toList(growable: false),
                ),
        );
      },
    );
  }

  IconData _noticeIcon(GlobalAppState state) => switch (state) {
    GlobalAppState.ready => Icons.check_circle_outline,
    GlobalAppState.offline => Icons.cloud_off_outlined,
    GlobalAppState.sessionExpired => Icons.lock_clock_outlined,
    GlobalAppState.migrationFailed => Icons.storage_outlined,
    GlobalAppState.updateRequired => Icons.system_update_outlined,
    GlobalAppState.maintenance => Icons.construction_outlined,
  };
}
