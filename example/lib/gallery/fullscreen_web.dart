import 'dart:js_interop';

@JS('document.fullscreenEnabled')
external JSBoolean? get _fullscreenEnabled;

@JS('document.documentElement.requestFullscreen')
external JSPromise<JSAny?> _requestFullscreen();

/// Whether this browser and embedding context allow fullscreen requests.
bool get supportsPresentationFullscreen => _fullscreenEnabled?.toDart ?? false;

/// Requests fullscreen directly from the toolbar's user gesture.
Future<bool> enterPresentationFullscreen() async {
  if (!supportsPresentationFullscreen) return false;
  try {
    await _requestFullscreen().toDart;
    return true;
  } catch (_) {
    // A browser may reject the request despite reporting support.
    return false;
  }
}
