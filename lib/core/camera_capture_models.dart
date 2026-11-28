enum WebCameraCaptureStatus {
  captured,
  cancelled,
  openGallery,
  fallback,
}

class WebCameraCaptureResult {
  final WebCameraCaptureStatus status;
  final List<int>? bytes;

  const WebCameraCaptureResult({
    required this.status,
    this.bytes,
  });
}
