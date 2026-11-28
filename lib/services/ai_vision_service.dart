import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../core/camera_capture_helper.dart';
import '../core/constants.dart';

class WasteClassificationResult {
  final bool isWaste;
  final String rejectionReason;
  final String summary;
  final String wasteType;
  final String severity;
  final double confidence;
  final bool containsFacesOrPlates;
  final bool usedLiveAi;
  final String providerLabel;
  final String? errorMessage;

  const WasteClassificationResult({
    this.isWaste = true,
    this.rejectionReason = '',
    this.summary = '',
    required this.wasteType,
    required this.severity,
    required this.confidence,
    required this.containsFacesOrPlates,
    required this.usedLiveAi,
    this.providerLabel = 'AI Vision',
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

class BeforeAfterVerificationResult {
  final bool cleared;
  final int matchScore;
  final String summary;
  final bool usedLiveAi;
  final String? errorMessage;

  const BeforeAfterVerificationResult({
    required this.cleared,
    required this.matchScore,
    required this.summary,
    required this.usedLiveAi,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

class AiVisionService {
  static const String _configuredProxyUrl = String.fromEnvironment(
    'VISION_PROXY_URL',
    defaultValue: '/api/vision',
  );

  /// Backend proxy URL; resolves relative `/api/vision` against production host
  /// on native mobile builds where there is no browser origin.
  static String get backendProxyUrl {
    if (!kIsWeb && _configuredProxyUrl.startsWith('/')) {
      return 'https://nagarnex.vercel.app$_configuredProxyUrl';
    }
    return _configuredProxyUrl;
  }

  static String get _prodFallbackProxyUrl =>
      'https://nagarnex.vercel.app${_configuredProxyUrl.startsWith('/') ? _configuredProxyUrl : '/api/vision'}';

  static Future<http.Response> _postToVisionProxy(
      Map<String, dynamic> payload) async {
    final body = jsonEncode(payload);
    final headers = const {'Content-Type': 'application/json'};
    final primaryUrl = backendProxyUrl;
    final canFallbackToProd = kIsWeb &&
        primaryUrl.startsWith('/') &&
        (Uri.base.host == 'localhost' ||
            Uri.base.host == '127.0.0.1' ||
            Uri.base.host.isEmpty);

    try {
      final res = await http
          .post(Uri.parse(primaryUrl), headers: headers, body: body)
          .timeout(const Duration(seconds: 45));
      if (canFallbackToProd &&
          (res.statusCode == 404 || res.statusCode == 405 || res.statusCode == 501)) {
        return await http
            .post(Uri.parse(_prodFallbackProxyUrl), headers: headers, body: body)
            .timeout(const Duration(seconds: 45));
      }
      return res;
    } catch (_) {
      if (canFallbackToProd) {
        return await http
            .post(Uri.parse(_prodFallbackProxyUrl), headers: headers, body: body)
            .timeout(const Duration(seconds: 45));
      }
      rethrow;
    }
  }

  static String get runtimeGeminiKey => AppConstants.geminiApiKey;
  static String get runtimeOpenRouterKey =>
      const String.fromEnvironment('OPENROUTER_API_KEY');

  static final Map<int, WasteClassificationResult> _classifyCache = {};

  static final RegExp _internalProviderPattern = RegExp(
    r'\b(gemini|ai\s*studio|aistudio|google|nvidia|nim|nemotron|openrouter|vercel|api[_\s-]*key|generativelanguage)\b',
    caseSensitive: false,
  );

  /// Strips internal AI model/provider/host names from user-facing messages.
  static String sanitizeUserMessage(String raw, {String fallback = 'Could not analyze image right now.'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _internalProviderPattern.hasMatch(trimmed)) {
      return fallback;
    }
    return trimmed;
  }

  static String detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static int _computeImageHash(Uint8List bytes) {
    if (bytes.isEmpty) return 0;
    final samples = <int>[bytes.length];
    const int sampleCount = 24;
    final step = bytes.length > sampleCount ? bytes.length ~/ sampleCount : 1;
    for (int i = 0; i < bytes.length; i += step) {
      samples.add(bytes[i]);
    }
    samples.add(bytes.last);
    return Object.hashAll(samples);
  }

  /// Strips EXIF metadata and compresses image bytes to a bounded resolution
  /// (using native browser canvas JPEG compression on web to avoid memory spikes).
  static Future<Uint8List> stripExifAndCompress(Uint8List rawBytes) async {
    if (rawBytes.isEmpty) return rawBytes;
    final webCompressed =
        await compressImageOnWeb(rawBytes, maxDim: 768, quality: 0.82);
    if (webCompressed != null && webCompressed.isNotEmpty) {
      return webCompressed;
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(rawBytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      final maxSide = w > h ? w : h;
      int? targetW;
      int? targetH;
      if (maxSide > 768) {
        if (w >= h) {
          targetW = 768;
        } else {
          targetH = 768;
        }
      }
      codec = await descriptor.instantiateCodec(
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {
      // Fallback to raw bytes if codec fails on an unsupported format
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
    return rawBytes;
  }

  /// Applies a pixel-level Gaussian blur to hide identifiable faces or
  /// vehicle license plates before uploading to public storage.
  static Future<Uint8List> applyPrivacyBlur(Uint8List imageBytes) async {
    ui.Codec? codec;
    ui.Image? src;
    ui.Picture? picture;
    ui.Image? blurred;
    try {
      codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      src = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0);
      canvas.drawImage(src, ui.Offset.zero, paint);
      picture = recorder.endRecording();
      blurred = await picture.toImage(src.width, src.height);
      final byteData =
          await blurred.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final webJpeg =
            await compressImageOnWeb(pngBytes, maxDim: 768, quality: 0.82);
        return webJpeg ?? pngBytes;
      }
    } catch (_) {
    } finally {
      blurred?.dispose();
      picture?.dispose();
      src?.dispose();
      codec?.dispose();
    }
    return imageBytes;
  }

  /// Classifies a waste photo via the secure backend proxy (`/api/vision`),
  /// or optional dev keys if configured. Never leaks internal AI provider names.
  static Future<WasteClassificationResult> classifyWasteImage({
    required Uint8List imageBytes,
    String? hintPlace,
  }) async {
    final cacheKey = _computeImageHash(imageBytes);
    final cached = _classifyCache[cacheKey];
    if (cached != null) return cached;

    final mime = detectMimeType(imageBytes);
    String proxyError = 'Could not analyze image right now.';
    try {
      final proxyRes = await _postToVisionProxy({
        'mode': 'classify',
        'mimeType': mime,
        'imageBase64': base64Encode(imageBytes),
      });

      final decoded = _tryDecodeMap(proxyRes.body);
      if (proxyRes.statusCode == 200 &&
          decoded != null &&
          decoded['error'] == null) {
        final res = _parseResult(decoded, 'AI Vision');
        if (_classifyCache.length >= 30) {
          _classifyCache.clear();
        }
        _classifyCache[cacheKey] = res;
        return res;
      }
      if (decoded != null && decoded['error'] != null) {
        proxyError = sanitizeUserMessage(decoded['error'].toString());
      } else {
        proxyError = 'AI service temporarily unavailable (${proxyRes.statusCode}).';
      }
    } catch (_) {
      proxyError = 'AI service unreachable. Please check your connection or retry.';
    }

    if (runtimeGeminiKey.isNotEmpty) {
      final res = await _classifyWithDirectVision(imageBytes, mime);
      if (res != null) return res;
    }

    if (runtimeOpenRouterKey.isNotEmpty) {
      final res = await _classifyWithOpenRouter(imageBytes, mime);
      if (res != null) return res;
    }

    return WasteClassificationResult(
      isWaste: false,
      rejectionReason: 'Not Detected by AI',
      summary: '',
      wasteType: 'Mixed/Debris',
      severity: 'Medium',
      confidence: 0.0,
      containsFacesOrPlates: false,
      usedLiveAi: false,
      providerLabel: 'Not Detected by AI',
      errorMessage: proxyError,
    );
  }

  static Map<String, dynamic>? _tryDecodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Future<WasteClassificationResult?> _classifyWithDirectVision(
      Uint8List imageBytes, String mime) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$runtimeGeminiKey',
      );
      final b64 = base64Encode(imageBytes);
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text':
                          'Analyze this Bengaluru street waste photo. Return ONLY valid JSON with keys: '
                              '"is_waste" (boolean), "rejection_reason" (string), "summary" (string), '
                              '"waste_type" (one of: "Plastic", "Wet/Food", "Glass", "E-Waste", "Mixed/Debris", "No Waste / Clean"), '
                              '"severity" (one of: "High", "Medium", "Low"), '
                              '"confidence" (number 0.0 to 1.0), '
                              '"contains_faces_or_plates" (boolean: true if any human face or vehicle license plate is visible).'
                    },
                    {
                      'inline_data': {
                        'mime_type': mime,
                        'data': b64,
                      }
                    }
                  ]
                }
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
              }
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final text = decoded['candidates']?[0]?['content']?['parts']?[0]
            ?['text'] as String?;
        if (text != null) {
          final parsed = jsonDecode(text) as Map<String, dynamic>;
          return _parseResult(parsed, 'AI Vision');
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<WasteClassificationResult?> _classifyWithOpenRouter(
      Uint8List imageBytes, String mime) async {
    try {
      final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final b64 = base64Encode(imageBytes);
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $runtimeOpenRouterKey',
            },
            body: jsonEncode({
              'model': 'openrouter/free',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text':
                          'Analyze this street waste photo. Return ONLY valid JSON (no markdown) with keys: '
                              '"is_waste" (boolean), "rejection_reason" (string), "summary" (string), '
                              '"waste_type" ("Plastic"|"Wet/Food"|"Glass"|"E-Waste"|"Mixed/Debris"|"No Waste / Clean"), '
                              '"severity" ("High"|"Medium"|"Low"), '
                              '"confidence" (0.0 to 1.0), '
                              '"contains_faces_or_plates" (boolean).'
                    },
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:$mime;base64,$b64'}
                    }
                  ]
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final raw =
            decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
        final cleaned =
            raw.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
        return _parseResult(parsed, 'AI Vision');
      }
    } catch (_) {}
    return null;
  }

  static WasteClassificationResult _parseResult(
      Map<String, dynamic> parsed, String provider) {
    final isWaste = parsed['is_waste'] as bool? ?? true;
    final rawReason = parsed['rejection_reason']?.toString().trim() ?? '';
    final rejectionReason = rawReason.isNotEmpty
        ? sanitizeUserMessage(
            rawReason,
            fallback: 'Image does not appear to show street waste or garbage.',
          )
        : (isWaste
            ? ''
            : 'Image does not appear to show street waste or garbage.');
    final summary = sanitizeUserMessage(
      parsed['summary']?.toString().trim() ?? '',
      fallback: '',
    );
    final wasteType = parsed['waste_type']?.toString() ?? 'Mixed/Debris';
    final severity = parsed['severity']?.toString() ?? 'Medium';
    return WasteClassificationResult(
      isWaste: isWaste,
      rejectionReason: rejectionReason,
      summary: summary,
      wasteType: !isWaste
          ? 'No Waste / Clean'
          : (AppConstants.wasteTypes.contains(wasteType)
              ? wasteType
              : 'Mixed/Debris'),
      severity:
          AppConstants.severities.contains(severity) ? severity : 'Medium',
      confidence: (parsed['confidence'] as num?)?.toDouble() ?? 0.91,
      containsFacesOrPlates:
          parsed['contains_faces_or_plates'] as bool? ?? false,
      usedLiveAi: true,
      providerLabel: provider,
    );
  }

  /// Compares Before and After images via the secure backend proxy (`/api/vision`).
  static Future<BeforeAfterVerificationResult> verifyBeforeAfter({
    required Uint8List afterBytes,
    Uint8List? beforeBytes,
    String? beforeUrl,
  }) async {
    final afterMime = detectMimeType(afterBytes);
    final beforeMime =
        beforeBytes != null ? detectMimeType(beforeBytes) : null;
    String proxyError = 'Not Detected by AI';
    try {
      final proxyRes = await _postToVisionProxy({
        'mode': 'verify',
        'mimeType': afterMime,
        'imageBase64': base64Encode(afterBytes),
        if (beforeBytes != null) ...{
          'beforeMimeType': beforeMime,
          'beforeImageBase64': base64Encode(beforeBytes),
        },
      });
      final decoded = _tryDecodeMap(proxyRes.body);
      if (proxyRes.statusCode == 200 &&
          decoded != null &&
          decoded['error'] == null) {
        return BeforeAfterVerificationResult(
          cleared: decoded['cleared'] as bool? ?? true,
          matchScore: (decoded['match_score'] as num?)?.toInt() ?? 92,
          summary: sanitizeUserMessage(
            decoded['summary']?.toString() ?? '',
            fallback: 'Street surface appears cleared.',
          ),
          usedLiveAi: true,
        );
      }
      if (decoded != null && decoded['error'] != null) {
        proxyError = sanitizeUserMessage(decoded['error'].toString());
      } else {
        proxyError = 'AI verification unavailable (${proxyRes.statusCode}).';
      }
    } catch (_) {
      proxyError = 'AI verification unreachable right now.';
    }

    if (runtimeGeminiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$runtimeGeminiKey',
        );
        final b64 = base64Encode(afterBytes);
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {
                        'text':
                            'Evaluate this "After" clearance photo for a street waste report. Return ONLY valid JSON: '
                                '{"cleared": boolean, "match_score": integer 0-100, "summary": string}.'
                      },
                      {
                        'inline_data': {
                          'mime_type': afterMime,
                          'data': b64,
                        }
                      }
                    ]
                  }
                ],
                'generationConfig': {
                  'responseMimeType': 'application/json',
                }
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final text = decoded['candidates']?[0]?['content']?['parts']?[0]
              ?['text'] as String?;
          if (text != null) {
            final parsed = jsonDecode(text) as Map<String, dynamic>;
            return BeforeAfterVerificationResult(
              cleared: parsed['cleared'] as bool? ?? true,
              matchScore: (parsed['match_score'] as num?)?.toInt() ?? 92,
              summary: sanitizeUserMessage(
                parsed['summary']?.toString() ?? '',
                fallback: 'Street surface appears cleared.',
              ),
              usedLiveAi: true,
            );
          }
        }
      } catch (_) {}
    }

    return BeforeAfterVerificationResult(
      cleared: false,
      matchScore: 0,
      summary: 'Not Detected by AI — $proxyError',
      usedLiveAi: false,
      errorMessage: proxyError,
    );
  }
}
