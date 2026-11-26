import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/geo_utils.dart';
import '../services/ai_vision_service.dart';
import '../services/app_state.dart';

class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key});

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  final GlobalKey _cropBoundaryKey = GlobalKey();
  final TransformationController _transformCtrl = TransformationController();

  Uint8List? _rawPhotoBytes;
  Uint8List? _croppedPhotoBytes;
  bool _exifStripped = false;
  bool _privacyBlurred = false;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;

  WasteClassificationResult? _aiResult;
  String _selectedWasteType = 'Mixed/Debris';
  String _selectedSeverity = 'High';

  int _presetIndex = 0;
  late double _lat =
      (AppConstants.bengaluruPresets[0]['lat'] as num).toDouble();
  late double _lng =
      (AppConstants.bengaluruPresets[0]['lng'] as num).toDouble();
  late String _wardName = AppConstants.bengaluruPresets[0]['ward'].toString();
  final TextEditingController _placeController = TextEditingController(
    text: AppConstants.bengaluruPresets[0]['place'].toString(),
  );

  @override
  void dispose() {
    _transformCtrl.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      final raw = await picked.readAsBytes();
      final stripped = await AiVisionService.stripExifAndCompress(raw);

      if (!mounted) return;
      _transformCtrl.value = Matrix4.identity();
      setState(() {
        _rawPhotoBytes = stripped;
        _croppedPhotoBytes = null;
        _exifStripped = true;
        _aiResult = null;
        _privacyBlurred = false;
        _isAnalyzing = true;
      });

      // Automatically classify the first photo and pre-fill parameters
      final res = await AiVisionService.classifyWasteImage(
        imageBytes: stripped,
        hintPlace: _placeController.text,
      );
      if (!mounted) return;
      setState(() {
        _aiResult = res;
        _selectedWasteType = res.wasteType;
        _selectedSeverity = res.severity;
        _privacyBlurred = !res.containsFacesOrPlates;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access camera/photo: $e')),
      );
    }
  }

  Future<Uint8List?> _captureCroppedViewport() async {
    try {
      final boundary = _cropBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return _rawPhotoBytes;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List() ?? _rawPhotoBytes;
    } catch (_) {
      return _rawPhotoBytes;
    }
  }

  Future<void> _checkWithAiAndMark() async {
    if (_rawPhotoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Click or upload a waste photo first, then tap Check with AI!'),
        ),
      );
      return;
    }
    setState(() => _isAnalyzing = true);

    final cropped = await _captureCroppedViewport();
    final targetBytes = cropped ?? _rawPhotoBytes!;
    final res = await AiVisionService.classifyWasteImage(
      imageBytes: targetBytes,
      hintPlace: _placeController.text,
    );

    if (!mounted) return;
    setState(() {
      _croppedPhotoBytes = targetBytes;
      _aiResult = res;
      _selectedWasteType = res.wasteType;
      _selectedSeverity = res.severity;
      _privacyBlurred = !res.containsFacesOrPlates;
      _isAnalyzing = false;
    });
  }

  void _selectPreset(int i) {
    final p = AppConstants.bengaluruPresets[i];
    setState(() {
      _presetIndex = i;
      _wardName = p['ward'].toString();
      _placeController.text = p['place'].toString();
      _lat = (p['lat'] as num).toDouble();
      _lng = (p['lng'] as num).toDouble();
    });
  }

  Future<void> _captureGps() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Browser GPS denied — tap any 1-click Bengaluru ward chip below.'),
          ),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final userPoint = LatLng(pos.latitude, pos.longitude);
      // Find nearest Bengaluru ward automatically
      int nearestIdx = 0;
      double minDist = double.infinity;
      for (int i = 0; i < AppConstants.bengaluruPresets.length; i++) {
        final p = AppConstants.bengaluruPresets[i];
        final d = GeoUtils.distanceMeters(
          userPoint,
          LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
        );
        if (d < minDist) {
          minDist = d;
          nearestIdx = i;
        }
      }
      if (!mounted) return;
      setState(() {
        _presetIndex = nearestIdx;
        _wardName =
            AppConstants.bengaluruPresets[nearestIdx]['ward'].toString();
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.forest,
          content: Text('Location locked: $_wardName (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Using selected Bengaluru ward coordinates for desktop.'),
        ),
      );
    }
  }

  Future<void> _submitReport() async {
    final uploadBytes = _croppedPhotoBytes ?? _rawPhotoBytes;
    if (uploadBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Capture or upload a photo first.')),
      );
      return;
    }
    if ((_aiResult?.containsFacesOrPlates ?? false) && !_privacyBlurred) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Faces or number plates detected. Enable Privacy Blur before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(nagarNexProvider.notifier).submitWasteReport(
          wardName: _wardName,
          placeName: _placeController.text.trim().isEmpty
              ? 'Bengaluru Street Spot'
              : _placeController.text.trim(),
          lat: _lat,
          lng: _lng,
          wasteType: _selectedWasteType,
          severity: _selectedSeverity,
          aiConfidence: _aiResult?.confidence ?? 0.90,
          photoBytes: uploadBytes,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.forest,
        content: Text(
          result.merged
              ? 'Merged into existing 150m blackspot (${result.report.reportCount} total reports)!'
              : 'New Bengaluru blackspot logged! +25 Civic Points.',
        ),
      ),
    );
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(nagarNexProvider);
    final enforceCameraOnly = appState.enforceCameraOnly;
    final enforceGpsOnly = appState.enforceGpsOnly;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '15-Second AI Waste Intake',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Click a live photo with Camera (or upload), drag & zoom to crop the waste area, then run AI Check & Mark to auto-fill details.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                ),
                const SizedBox(height: 18),

                // Interactive Camera / Upload / Crop / AI Marking Box
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _aiResult != null
                          ? AppColors.emerald
                          : AppColors.border,
                      width: _aiResult != null ? 1.8 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _rawPhotoBytes != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            // Croppable & Draggable Viewport
                            RepaintBoundary(
                              key: _cropBoundaryKey,
                              child: InteractiveViewer(
                                transformationController: _transformCtrl,
                                minScale: 1.0,
                                maxScale: 3.5,
                                panEnabled: true,
                                scaleEnabled: true,
                                child: ImageFiltered(
                                  imageFilter: _privacyBlurred &&
                                          (_aiResult?.containsFacesOrPlates ??
                                              false)
                                      ? ui.ImageFilter.blur(
                                          sigmaX: 5, sigmaY: 5)
                                      : ui.ImageFilter.blur(
                                          sigmaX: 0, sigmaY: 0),
                                  child: Image.memory(
                                    _rawPhotoBytes!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            ),

                            // Subtle Crop Guide Frame
                            IgnorePointer(
                              child: Container(
                                margin: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _aiResult != null
                                        ? AppColors.emeraldMint
                                        : Colors.white.withValues(alpha: 0.7),
                                    width: _aiResult != null ? 2.2 : 1.2,
                                  ),
                                ),
                              ),
                            ),

                            // AI Detection Marking Overlay after AI check
                            if (_aiResult != null)
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.forest
                                        .withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_awesome_rounded,
                                          size: 14,
                                          color: AppColors.emeraldMint),
                                      const SizedBox(width: 6),
                                      Text(
                                        'AI Marked: ${_aiResult!.wasteType} · ${_aiResult!.severity} (${(_aiResult!.confidence * 100).round()}%)',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            if (_exifStripped)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.ink.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'EXIF Stripped · Drag/Zoom to Crop',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                            Positioned(
                              top: 10,
                              right: 10,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: _isAnalyzing
                                        ? null
                                        : () => _transformCtrl.value =
                                            Matrix4.identity(),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.surface,
                                      foregroundColor: AppColors.ink,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.crop_free_rounded,
                                        size: 15),
                                    label: const Text('Reset Crop',
                                        style: TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton.tonalIcon(
                                    onPressed: _isAnalyzing
                                        ? null
                                        : () => setState(() {
                                              _rawPhotoBytes = null;
                                              _croppedPhotoBytes = null;
                                              _aiResult = null;
                                              _exifStripped = false;
                                            }),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.surface,
                                      foregroundColor: AppColors.ink,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 15),
                                    label: const Text('Retake',
                                        style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_camera_outlined,
                                  size: 36, color: AppColors.inkMuted),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () =>
                                        _pickPhoto(ImageSource.camera),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.forest,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.camera_alt_rounded,
                                        size: 18),
                                    label: const Text('Click Photo (Camera)'),
                                  ),
                                  if (!enforceCameraOnly)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _pickPhoto(ImageSource.gallery),
                                      icon: const Icon(Icons.upload_rounded,
                                          size: 18),
                                      label: const Text('Upload Photo'),
                                    )
                                  else
                                    const Chip(
                                      label: Text('Camera-Only Enforced',
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAnalyzing ? null : _checkWithAiAndMark,
                    style: FilledButton.styleFrom(
                      backgroundColor: _rawPhotoBytes == null
                          ? AppColors.forest
                          : AppColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      _isAnalyzing
                          ? 'Analyzing Cropped Area with Vision AI...'
                          : (_aiResult == null
                              ? 'Check with AI & Auto-Fill Details'
                              : 'Re-Check Cropped Area with AI'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                if (_isAnalyzing) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(color: AppColors.emerald),
                ],

                if (_aiResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.emerald),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Filled by ${_aiResult!.providerLabel}: ${_aiResult!.wasteType} · ${_aiResult!.severity} Severity (${(_aiResult!.confidence * 100).round()}% confidence)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        if (_aiResult!.containsFacesOrPlates) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Privacy Flag: Face/Number Plate detected — Apply Blur',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger,
                              ),
                            ),
                            value: _privacyBlurred,
                            activeThumbColor: AppColors.forest,
                            onChanged: (v) =>
                                setState(() => _privacyBlurred = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedWasteType,
                        decoration: const InputDecoration(
                          labelText: 'Waste Category',
                          border: OutlineInputBorder(),
                        ),
                        items: AppConstants.wasteTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedWasteType = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSeverity,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: AppConstants.severities
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedSeverity = v);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '1-Click Location Setup',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _captureGps,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emeraldSoft,
                        foregroundColor: AppColors.forest,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('1-Click Detect GPS',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!enforceGpsOnly)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: List.generate(
                      AppConstants.bengaluruPresets.length,
                      (i) {
                        final p = AppConstants.bengaluruPresets[i];
                        final active = _presetIndex == i;
                        final shortWard =
                            p['ward'].toString().split(' ').skip(2).join(' ');
                        return ChoiceChip(
                          label: Text(shortWard),
                          selected: active,
                          selectedColor: AppColors.forest,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? Colors.white
                                : AppColors.inkSecondary,
                          ),
                          onSelected: (_) => _selectPreset(i),
                        );
                      },
                    ),
                  )
                else
                  const Text(
                    'Live GPS Enforcement active — tap "1-Click Detect GPS" above.',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emeraldDark),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    labelText: 'Street / Landmark ($_wardName)',
                    suffixText:
                        '${_lat.toStringAsFixed(3)}, ${_lng.toStringAsFixed(3)}',
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Clustering & Submitting...'
                          : 'Submit Waste Report (Auto-Cluster <=150m)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
