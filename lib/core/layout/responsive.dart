import 'package:flutter/material.dart';

enum ControlRoomWindowSize { phone, tablet, desktop }

abstract final class ControlRoomBreakpoints {
  static const phone = 600.0;
  static const desktop = 1000.0;

  static ControlRoomWindowSize classify(double width) {
    if (width < phone) return ControlRoomWindowSize.phone;
    if (width < desktop) return ControlRoomWindowSize.tablet;
    return ControlRoomWindowSize.desktop;
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1240,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final windowSize = ControlRoomBreakpoints.classify(availableWidth);
        final horizontalPadding = switch (windowSize) {
          ControlRoomWindowSize.phone => 16.0,
          ControlRoomWindowSize.tablet => 24.0,
          ControlRoomWindowSize.desktop => 32.0,
        };
        return SizedBox(
          width: availableWidth,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  40,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
