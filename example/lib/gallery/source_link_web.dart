import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);

/// Opens a trusted repository URL without handing it the window opener.
bool openSourceUrl(String url) {
  _open(url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
  return true;
}
