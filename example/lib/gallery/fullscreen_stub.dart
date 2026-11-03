/// Native hosts use their own window controls.
bool get supportsPresentationFullscreen => false;

/// No browser document exists on native hosts.
Future<bool> enterPresentationFullscreen() async => false;
