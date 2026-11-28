import 'dart:typed_data';
import 'camera_capture_models.dart';

export 'camera_capture_models.dart';

Future<WebCameraCaptureResult> openWebLiveCamera({
  bool allowGallery = true,
}) async {
  return const WebCameraCaptureResult(status: WebCameraCaptureStatus.fallback);
}

Future<Uint8List?> compressImageOnWeb(
  Uint8List rawBytes, {
  int maxDim = 768,
  double quality = 0.82,
}) async {
  return null;
}
