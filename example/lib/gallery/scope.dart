import 'package:flutter/widgets.dart';

/// Signals that the gallery already provides page navigation and a title.
class GalleryDemoScope extends InheritedWidget {
  /// Wraps the active example.
  const GalleryDemoScope({super.key, required super.child});

  /// Whether this screen is hosted in the interactive gallery.
  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GalleryDemoScope>() != null;

  @override
  bool updateShouldNotify(GalleryDemoScope oldWidget) => false;
}
