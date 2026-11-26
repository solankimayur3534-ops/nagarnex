import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/geo_utils.dart';
import '../models/collection_center.dart';
import '../models/waste_report.dart';
import '../services/app_state.dart';
import '../widgets/verify_proof_modal.dart';

enum MapFilter { all, plasticMixed, wetFood, eWasteDebris, cleared }

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final MapController _mapController = MapController();
  MapFilter _filter = MapFilter.all;
  bool _showCenters = true;
  String? _selectedReportId;
  String? _selectedCenterId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nagarNexProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 960;

    final filteredReports = state.reports.where((r) {
      switch (_filter) {
        case MapFilter.all:
          return true;
        case MapFilter.plasticMixed:
          return r.wasteType == 'Plastic' || r.wasteType == 'Mixed/Debris';
        case MapFilter.wetFood:
          return r.wasteType == 'Wet/Food';
        case MapFilter.eWasteDebris:
          return r.wasteType == 'E-Waste' || r.wasteType == 'Glass';
        case MapFilter.cleared:
          return r.status == ReportStatus.verifiedCleared;
      }
    }).toList();

    final WasteReport? selectedReport = _selectedReportId == null
        ? (filteredReports.isNotEmpty ? filteredReports.first : null)
        : state.reports.cast<WasteReport?>().firstWhere(
              (r) => r?.id == _selectedReportId,
              orElse: () => null,
            );

    final CollectionCenter? selectedCenter = _selectedCenterId == null
        ? null
        : state.centers.cast<CollectionCenter?>().firstWhere(
              (c) => c?.id == _selectedCenterId,
              orElse: () => null,
            );

    final telemetryBar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldMint.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '● Live Sync Active • Bengaluru 2026',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const Text(
                '• Citizen-Verified Waste Intelligence',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSecondary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Ward Circle 4',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 14, color: AppColors.inkSecondary),
                  SizedBox(width: 4),
                  Text(
                    'Public EXIF Stripped • Auto-Masking On',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.inkSecondary),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed_rounded,
                        size: 13, color: AppColors.ink),
                    SizedBox(width: 4),
                    Text(
                      'GPS ±10m Precision',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final filterStrip = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PillFilter(
          label: 'All Spots (${state.reports.length})',
          active: _filter == MapFilter.all,
          activeBg: AppColors.forest,
          onTap: () => setState(() => _filter = MapFilter.all),
        ),
        _PillFilter(
          label: 'Plastic & Mixed',
          active: _filter == MapFilter.plasticMixed,
          activeBg: AppColors.forest,
          onTap: () => setState(() => _filter = MapFilter.plasticMixed),
        ),
        _PillFilter(
          label: 'Wet/Food',
          active: _filter == MapFilter.wetFood,
          activeBg: AppColors.forest,
          onTap: () => setState(() => _filter = MapFilter.wetFood),
        ),
        _PillFilter(
          label: 'E-Waste & Debris',
          active: _filter == MapFilter.eWasteDebris,
          activeBg: AppColors.forest,
          onTap: () => setState(() => _filter = MapFilter.eWasteDebris),
        ),
        _PillFilter(
          label:
              'Verified Cleared (${state.reports.where((r) => r.status == ReportStatus.verifiedCleared).length})',
          active: _filter == MapFilter.cleared,
          activeBg: AppColors.emerald,
          softMint: true,
          onTap: () => setState(() => _filter = MapFilter.cleared),
        ),
        _PillFilter(
          label: 'Collection Centers (Dry/Wet)',
          active: _showCenters,
          activeBg: AppColors.info,
          softBlue: true,
          onTap: () => setState(() => _showCenters = !_showCenters),
        ),
      ],
    );

    final mapCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: isWide ? 520 : 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: AppConstants.bengaluruCenter,
                  initialZoom: 12.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nagarnex.app',
                  ),
                  MarkerLayer(
                    markers: [
                      ...filteredReports.map((report) {
                        final isCleared =
                            report.status == ReportStatus.verifiedCleared;
                        final color = isCleared
                            ? AppColors.emerald
                            : (report.isRecurring
                                ? AppColors.danger
                                : AppColors.warning);

                        return Marker(
                          point: LatLng(report.lat, report.lng),
                          width: 46,
                          height: 46,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedReportId = report.id;
                                _selectedCenterId = null;
                              });
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isCleared
                                        ? Icons.check_rounded
                                        : Icons.warning_amber_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.ink,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${report.reportCount}',
                                      style: const TextStyle(
                                        fontSize: 10,
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
                      }),
                      if (_showCenters)
                        ...state.centers.map((center) {
                          return Marker(
                            point: LatLng(center.lat, center.lng),
                            width: 34,
                            height: 34,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCenterId = center.id;
                                  _selectedReportId = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.forest,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.recycling_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Auto-Clustered (150m Radius)  •  Bengaluru',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              if (selectedReport != null || selectedCenter != null)
                Positioned(
                  bottom: 14,
                  left: 14,
                  right: isWide ? null : 14,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: selectedReport != null
                        ? _FloatingSpotCard(
                            report: selectedReport,
                            onVerify: () async {
                              final res = await showDialog<bool>(
                                context: context,
                                builder: (_) =>
                                    VerifyProofModal(report: selectedReport),
                              );
                              if (res == true && mounted) {
                                setState(() => _selectedReportId = null);
                              }
                            },
                          )
                        : _FloatingCenterCard(
                            center: selectedCenter!,
                            onClose: () =>
                                setState(() => _selectedCenterId = null),
                          ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendDot(color: AppColors.danger, label: 'Repeat Blackspot'),
            _LegendDot(color: AppColors.warning, label: 'Pending Check'),
            _LegendDot(color: AppColors.emerald, label: 'Verified Cleared'),
            _LegendDot(color: AppColors.forest, label: 'Collection Point'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Map rendered with OpenStreetMap telemetry (Bengaluru 2026)',
          style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fast Civic Logging Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAST CIVIC LOGGING',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Report a Waste Blackspot in 15 Seconds',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldMint.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: AppColors.forest, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Snap one live photo. Vision AI estimates waste category & severity, strips EXIF, and prevents duplicate ward pins within 150m.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MiniInfoChip(label: 'GPS ±10m'),
                  _MiniInfoChip(label: 'Auto-Blur Faces & Plates'),
                  _MiniInfoChip(label: 'Public EXIF Stripped'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/intake'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text(
                    'Snap & Classify Waste',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 18, color: AppColors.forest),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Neighborhood Activity Feed',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Sort: Urgency',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filteredReports.take(4).map((r) {
          final isCleared = r.status == ReportStatus.verifiedCleared;
          final isOverdue = r.slaDeadline.isBefore(DateTime.now()) && !isCleared;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                _mapController.move(LatLng(r.lat, r.lng), 14.0);
                setState(() {
                  _selectedReportId = r.id;
                  _selectedCenterId = null;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedReportId == r.id
                        ? AppColors.forest
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.placeName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${r.wardName} • ${r.reportCount} Reports Merged',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOverdue || r.isRecurring
                                ? AppColors.dangerSoft
                                : AppColors.emeraldMint.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isOverdue
                                ? '• Repeat Blackspot'
                                : (isCleared
                                    ? 'Verified Cleared ✓'
                                    : r.wasteType),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isOverdue || r.isRecurring
                                  ? AppColors.danger
                                  : AppColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          isCleared
                              ? 'Cleared in ${r.clearanceDurationLabel}'
                              : GeoUtils.formatSlaRemaining(r.slaDeadline),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isCleared
                                ? AppColors.emeraldDark
                                : AppColors.danger,
                          ),
                        ),
                        const Spacer(),
                        if (!isCleared && r.isRecurring)
                          FilledButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(nagarNexProvider.notifier)
                                  .createMicroDrive(
                                    reportId: r.id,
                                    title: 'Clean-Up Drive · ${r.placeName}',
                                    wardName: r.wardName,
                                    meetingPoint: r.placeName,
                                    driveTime: DateTime.now()
                                        .add(const Duration(days: 1)),
                                  );
                              if (!context.mounted) return;
                              context.go('/drives');
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.flash_on_rounded, size: 14),
                            label: const Text('Start Clean-Up Drive',
                                style: TextStyle(fontSize: 11.5)),
                          )
                        else if (!isCleared)
                          FilledButton(
                            onPressed: () async {
                              await showDialog<bool>(
                                context: context,
                                builder: (_) => VerifyProofModal(report: r),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.forest,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Verify Fix',
                                style: TextStyle(fontSize: 11.5)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              telemetryBar,
              const SizedBox(height: 14),
              filterStrip,
              const SizedBox(height: 18),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: mapCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: rightColumn),
                  ],
                )
              else
                Column(
                  children: [
                    mapCard,
                    const SizedBox(height: 20),
                    rightColumn,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillFilter extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeBg;
  final bool softMint;
  final bool softBlue;
  final VoidCallback onTap;

  const _PillFilter({
    required this.label,
    required this.active,
    required this.activeBg,
    required this.onTap,
    this.softMint = false,
    this.softBlue = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.surface;
    Color fg = AppColors.ink;
    if (active) {
      bg = activeBg;
      fg = Colors.white;
    } else if (softMint) {
      bg = AppColors.emeraldMint.withValues(alpha: 0.4);
      fg = AppColors.forest;
    } else if (softBlue) {
      bg = AppColors.infoSoft;
      fg = AppColors.info;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? bg : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _FloatingSpotCard extends StatelessWidget {
  final WasteReport report;
  final VoidCallback onVerify;

  const _FloatingSpotCard({
    required this.report,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final cleared = report.status == ReportStatus.verifiedCleared;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emeraldMint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '● AI: ${report.wasteType} • ${report.severity} Severity • ${(report.aiConfidence * 100).round()}%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.placeName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${report.wardName} • ${report.reportCount} Merged • ${cleared ? "Verified Cleared" : GeoUtils.formatSlaRemaining(report.slaDeadline)}',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.inkSecondary,
            ),
          ),
          if (!cleared) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onVerify,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Verify Fix →',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FloatingCenterCard extends StatelessWidget {
  final CollectionCenter center;
  final VoidCallback onClose;

  const _FloatingCenterCard({required this.center, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  center.centerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Text(
            '${center.address} • ${center.wardName}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: center.acceptedTypes
                .map((t) => _MiniInfoChip(label: 'Accepts $t'))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final String label;
  const _MiniInfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSecondary,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}
