import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'camera_capture_models.dart';

export 'camera_capture_models.dart';

@JS('nnOpenLiveCamera')
external JSPromise<JSString?> _jsOpenLiveCamera(JSBoolean allowGallery);

@JS('nnCompressImageBytes')
external JSPromise<JSString?> _jsCompressImageBytes(
  JSUint8Array bytes,
  JSNumber maxDim,
  JSNumber quality,
);

Future<WebCameraCaptureResult> openWebLiveCamera({
  bool allowGallery = true,
}) async {
  try {
    final res = await _jsOpenLiveCamera(allowGallery.toJS).toDart;
    final val = res?.toDart;
    if (val == null || val == 'FALLBACK') {
      return const WebCameraCaptureResult(
        status: WebCameraCaptureStatus.fallback,
      );
    }
    if (val == 'CANCEL') {
      return const WebCameraCaptureResult(
        status: WebCameraCaptureStatus.cancelled,
      );
    }
    if (val == 'GALLERY') {
      return const WebCameraCaptureResult(
        status: WebCameraCaptureStatus.openGallery,
      );
    }
    if (val.startsWith('OK:')) {
      final b64 = val.substring(3);
      if (b64.isNotEmpty) {
        return WebCameraCaptureResult(
          status: WebCameraCaptureStatus.captured,
          bytes: base64Decode(b64),
        );
      }
    }
  } catch (_) {}
  return const WebCameraCaptureResult(status: WebCameraCaptureStatus.fallback);
}

Future<Uint8List?> compressImageOnWeb(
  Uint8List rawBytes, {
  int maxDim = 768,
  double quality = 0.82,
}) async {
  try {
    final res = await _jsCompressImageBytes(
      rawBytes.toJS,
      maxDim.toJS,
      quality.toJS,
    ).toDart;
    final b64 = res?.toDart;
    if (b64 != null && b64.isNotEmpty) {
      return base64Decode(b64);
    }
  } catch (_) {}
  return null;
}
