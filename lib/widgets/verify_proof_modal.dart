import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/geo_utils.dart';
import '../models/waste_report.dart';
import '../services/ai_vision_service.dart';
import '../services/app_state.dart';

class VerifyProofModal extends ConsumerStatefulWidget {
  final WasteReport report;

  const VerifyProofModal({super.key, required this.report});

  @override
  ConsumerState<VerifyProofModal> createState() => _VerifyProofModalState();
}

class _VerifyProofModalState extends ConsumerState<VerifyProofModal> {
  Uint8List? _afterBytes;
  bool _demoGpsOverride = true;
  bool _isChecking = false;
  double? _distanceMeters;
  BeforeAfterVerificationResult? _aiResult;
  String? _error;

  Future<void> _pickAfterPhoto() async {
    setState(() {
      _error = null;
      _aiResult = null;
    });

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isChecking = true);
      final rawBytes = await picked.readAsBytes();
      final stripped = await AiVisionService.stripExifAndCompress(rawBytes);

      LatLng verifyPoint = LatLng(widget.report.lat, widget.report.lng);
      if (!_demoGpsOverride) {
        try {
          final pos = await Geolocator.getCurrentPosition();
          verifyPoint = LatLng(pos.latitude, pos.longitude);
        } catch (_) {}
      }

      final dist = GeoUtils.distanceMeters(
        LatLng(widget.report.lat, widget.report.lng),
        verifyPoint,
      );

      final cachedBefore = ref
          .read(nagarNexProvider)
          .localPhotoCache[widget.report.beforePhotoUrl];
      final aiRes = await AiVisionService.verifyBeforeAfter(
        afterBytes: stripped,
        beforeBytes: cachedBefore,
        beforeUrl: widget.report.beforePhotoUrl,
      );

      if (!mounted) return;
      setState(() {
        _afterBytes = stripped;
        _distanceMeters = dist;
        _aiResult = aiRes;
        _isChecking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _error = 'Could not read selected image: $e';
      });
    }
  }

  Future<void> _confirmClosure() async {
    final bytes = _afterBytes ?? Uint8List(0);
    if (bytes.isEmpty) {
      setState(
          () => _error = 'Please upload an "After" clearance photo first.');
      return;
    }
    if (!_demoGpsOverride &&
        (_distanceMeters ?? 999) > AppConstants.verifyProximityMeters) {
      setState(() => _error =
          'You are ${_distanceMeters?.round()}m away. Must be within 50m (or enable Demo GPS Override).');
      return;
    }

    setState(() => _isChecking = true);
    await ref.read(nagarNexProvider.notifier).submitVerification(
          report: widget.report,
          afterPhotoBytes: bytes,
          markClearedNow: true,
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cachedBefore = ref
        .watch(nagarNexProvider)
        .localPhotoCache[widget.report.beforePhotoUrl];
    final currentVotes = widget.report.verifyVotes;
    final pct = ((currentVotes / AppConstants.requiredVerifyVotes) * 100)
        .clamp(0, 100)
        .round();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldMint.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '● Citizen Clearance Audit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        _TagPill(label: 'Ticket #${widget.report.id.toUpperCase()}'),
                        _TagPill(label: widget.report.wardName),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Verify Street Waste Clearance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Citizen cleanup report submitted photographic proof for ${widget.report.placeName}.',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 16),

              // Side-by-side Before / After Split Frame
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(
                      child: _SplitFrame(
                        badge: widget.report.wasteType,
                        footer: 'BEFORE — Reported Blackspot',
                        bytes: cachedBefore,
                        hint: 'Reported Street Spot',
                        isAfter: false,
                      ),
                    ),
                    Container(width: 2, height: 190, color: Colors.white),
                    Expanded(
                      child: _SplitFrame(
                        badge: _aiResult != null
                            ? 'AI Visual Match: ${_aiResult!.matchScore}%'
                            : 'Upload After Photo',
                        footer: 'AFTER — Cleared Proof',
                        bytes: _afterBytes,
                        hint: 'Tap to Upload After Photo',
                        isAfter: true,
                        onTap: _pickAfterPhoto,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AuditMetaBox(
                      title: 'Location Match',
                      sub: _demoGpsOverride
                          ? 'Demo GPS Override Active'
                          : 'Within ${_distanceMeters?.round() ?? 0}m of pin',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AuditMetaBox(
                      title: 'AI Visual Check',
                      sub: _aiResult != null
                          ? '${_aiResult!.matchScore}% cleared'
                          : 'Awaiting After photo',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: _AuditMetaBox(
                      title: 'Public EXIF',
                      sub: 'Stripped for citizen privacy',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Demo Mode: GPS <=50m Proximity Override for Judges',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _demoGpsOverride,
                      activeThumbColor: AppColors.forest,
                      onChanged: (v) => setState(() => _demoGpsOverride = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Neighbor Consensus Verification',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldMint.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$currentVotes of ${AppConstants.requiredVerifyVotes} Confirmed ($pct%)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (currentVotes / AppConstants.requiredVerifyVotes)
                            .clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Civic Resolution Rule: Status marks as Verified Cleared once After-photo proof & local consensus are confirmed.',
                      style:
                          TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),

              if (_isChecking) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: AppColors.emerald),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isChecking
                          ? null
                          : (_afterBytes == null
                              ? _pickAfterPhoto
                              : _confirmClosure),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emeraldDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(_afterBytes == null
                          ? Icons.upload_rounded
                          : Icons.check_circle_outline_rounded),
                      label: Text(
                        _afterBytes == null
                            ? 'Upload After Photo'
                            : 'Confirm Cleared ✓',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.dangerSoft,
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Still Uncleared ×',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSecondary,
        ),
      ),
    );
  }
}

class _SplitFrame extends StatelessWidget {
  final String badge;
  final String footer;
  final Uint8List? bytes;
  final String hint;
  final bool isAfter;
  final VoidCallback? onTap;

  const _SplitFrame({
    required this.badge,
    required this.footer,
    required this.bytes,
    required this.hint,
    required this.isAfter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 190,
        color: AppColors.surfaceMuted,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAfter
                          ? Icons.add_a_photo_outlined
                          : Icons.photo_camera_back_outlined,
                      size: 30,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  footer,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditMetaBox extends StatelessWidget {
  final String title;
  final String sub;
  const _AuditMetaBox({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
