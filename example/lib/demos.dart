// Run: flutter run -d web-server -t lib/demos.dart
import 'package:flutter/material.dart';

import 'gallery/app.dart';
export 'gallery/app.dart' show DemosApp;
export 'gallery/registry.dart' show DemoEntry, demoEntries, galleryEntries;

void main() => runApp(const DemosApp());
