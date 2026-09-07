import 'package:flutter/material.dart';

import 'help_guides.dart';
import 'help_screen.dart';

class HelpNavigationScope extends InheritedWidget {
  const HelpNavigationScope({
    super.key,
    required this.onOpenGuide,
    required super.child,
  });

  final ValueChanged<String> onOpenGuide;

  static HelpNavigationScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HelpNavigationScope>();

  @override
  bool updateShouldNotify(HelpNavigationScope oldWidget) =>
      onOpenGuide != oldWidget.onOpenGuide;
}

class SmartHelpButton extends StatelessWidget {
  const SmartHelpButton({
    super.key,
    required this.guideId,
    this.tooltip = 'Open help',
  });

  final String guideId;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final guide = helpGuides.where((item) => item.id == guideId).firstOrNull;
    if (guide == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'Help: ${guide.title}',
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: () {
            final shell = HelpNavigationScope.maybeOf(context);
            if (shell != null) {
              shell.onOpenGuide(guideId);
              return;
            }
            openHelpGuide(context, guideId);
          },
          icon: const Icon(Icons.help_outline),
          color: const Color(0xFF00D9F5),
        ),
      ),
    );
  }
}
