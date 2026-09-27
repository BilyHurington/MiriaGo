import 'package:flutter/widgets.dart';

import '../plan/pilgrimage_models.dart';

class AnitabiImageSourceScope extends InheritedWidget {
  const AnitabiImageSourceScope({
    required this.source,
    required super.child,
    super.key,
  });

  final AnitabiImageSource source;

  static AnitabiImageSource of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AnitabiImageSourceScope>()
            ?.source ??
        AnitabiImageSource.auto;
  }

  @override
  bool updateShouldNotify(AnitabiImageSourceScope oldWidget) {
    return source != oldWidget.source;
  }
}
