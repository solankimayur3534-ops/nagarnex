import 'dart:js_interop';

@JS('nnEnterFullscreenIfMobile')
external void _jsEnterFullscreenIfMobile();

@JS('nnToggleFullscreen')
external void _jsToggleFullscreen();

void enterFullscreenIfMobile() {
  try {
    _jsEnterFullscreenIfMobile();
  } catch (_) {}
}

void toggleFullscreen() {
  try {
    _jsToggleFullscreen();
  } catch (_) {}
}
