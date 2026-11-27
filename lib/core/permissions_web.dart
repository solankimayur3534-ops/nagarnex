import 'dart:js_interop';

@JS('nnCheckCameraPermission')
external JSPromise<JSBoolean> _jsCheckCameraPermission();

@JS('nnRequestCameraPermission')
external JSPromise<JSBoolean> _jsRequestCameraPermission();

Future<bool> isCameraPermissionGranted() async {
  try {
    final res = await _jsCheckCameraPermission().toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> requestCameraPermission() async {
  try {
    final res = await _jsRequestCameraPermission().toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}
