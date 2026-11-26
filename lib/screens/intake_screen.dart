import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import '../services/ai_vision_service.dart';
import '../services/app_state.dart';

class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key});

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  Uint8List? _photoBytes;
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
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _isAnalyzing = true;
        _aiResult = null;
      });

      final raw = await picked.readAsBytes();
      final stripped = await AiVisionService.stripExifAndCompress(raw);
      final res = await AiVisionService.classifyWasteImage(
        imageBytes: stripped,
        hintPlace: _placeController.text,
      );

      if (!mounted) return;
      setState(() {
        _photoBytes = stripped;
        _exifStripped = true;
        _privacyBlurred = !res.containsFacesOrPlates;
        _aiResult = res;
        _selectedWasteType = res.wasteType;
        _selectedSeverity = res.severity;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load photo: $e')),
      );
    }
  }

  Future<void> _useSampleDemoPhoto() async {
    setState(() => _isAnalyzing = true);
    // Generate a clean 320x180 placeholder PNG in memory so judges can test without a file
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 180), paint);
    final accent = Paint()..color = AppColors.emerald;
    canvas.drawCircle(const Offset(160, 90), 36, accent);
    final pic = recorder.endRecording();
    final img = await pic.toImage(320, 180);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    final bytes = data!.buffer.asUint8List();

    final res = await AiVisionService.classifyWasteImage(
      imageBytes: bytes,
      hintPlace: _placeController.text,
    );

    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _exifStripped = true;
      _privacyBlurred = true;
      _aiResult = res;
      _selectedWasteType = res.wasteType;
      _selectedSeverity = res.severity;
      _isAnalyzing = false;
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
                'Browser GPS denied — using selected Bengaluru preset coordinates.'),
          ),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Using Bengaluru fallback coordinates for desktop browser.'),
        ),
      );
    }
  }

  Future<void> _submitReport() async {
    if (_photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Upload a photo or load a sample photo first.')),
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
          photoBytes: _photoBytes!,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.emeraldDark,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
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
                  'Upload a photo. EXIF metadata is stripped automatically, Vision AI classifies waste & severity, and reports within 150m merge into one blackspot.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                ),
                const SizedBox(height: 20),

                // Photo capture box
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _photoBytes != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ImageFiltered(
                              imageFilter: _privacyBlurred &&
                                      (_aiResult?.containsFacesOrPlates ??
                                          false)
                                  ? ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5)
                                  : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                              child: Image.memory(_photoBytes!,
                                  fit: BoxFit.cover),
                            ),
                            if (_exifStripped)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.ink,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'EXIF Stripped',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: FilledButton.tonalIcon(
                                onPressed: _isAnalyzing
                                    ? null
                                    : () => setState(() {
                                          _photoBytes = null;
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
                                    size: 16),
                                label: const Text('Change Photo',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_a_photo_outlined,
                                  size: 34, color: AppColors.inkMuted),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _pickAndAnalyzePhoto,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.ink,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.upload_rounded,
                                        size: 18),
                                    label: const Text('Upload Photo'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _useSampleDemoPhoto,
                                    child: const Text('Use Demo Sample'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),

                if (_isAnalyzing) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(color: AppColors.emerald),
                  const SizedBox(height: 6),
                  const Text(
                    'Stripping EXIF & running AI waste classification...',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                  ),
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
                          'AI Detected: ${_aiResult!.wasteType} · ${_aiResult!.severity} Severity (${(_aiResult!.confidence * 100).round()}% conf)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldDark,
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
                            activeThumbColor: AppColors.emeraldDark,
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

                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _presetIndex,
                  decoration: const InputDecoration(
                    labelText: 'Bengaluru Location / Demo GPS Preset',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    AppConstants.bengaluruPresets.length,
                    (i) {
                      final p = AppConstants.bengaluruPresets[i];
                      return DropdownMenuItem(
                        value: i,
                        child: Text('${p['ward']} — ${p['place']}'),
                      );
                    },
                  ),
                  onChanged: (i) {
                    if (i == null) return;
                    final p = AppConstants.bengaluruPresets[i];
                    setState(() {
                      _presetIndex = i;
                      _wardName = p['ward'].toString();
                      _placeController.text = p['place'].toString();
                      _lat = (p['lat'] as num).toDouble();
                      _lng = (p['lng'] as num).toDouble();
                    });
                  },
                ),

                const SizedBox(height: 14),
                TextFormField(
                  controller: _placeController,
                  decoration: const InputDecoration(
                    labelText: 'Street / Landmark Name',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'GPS: ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _captureGps,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Use Browser GPS'),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
