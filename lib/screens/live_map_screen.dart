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
import '../services/supabase_service.dart';
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
  String _focusWard = 'All Bengaluru';
  String? _selectedReportId;
  String? _selectedCenterId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nagarNexProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 960;
    final wardStats = state.wardStats;

    final filteredReports = state.reports.where((r) {
      if (_focusWard != 'All Bengaluru' && r.wardName != _focusWard) {
        return false;
      }
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

    final clearedCount = state.reports
        .where((r) => r.status == ReportStatus.verifiedCleared)
        .length;
    final totalMerged =
        state.reports.fold<int>(0, (sum, r) => sum + r.reportCount);

    final wardOptions = <String>[
      'All Bengaluru',
      ...state.reports.map((r) => r.wardName).toSet(),
    ];

    final filterStrip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PillFilter(
            label: 'All Spots (${state.reports.length})',
            active: _filter == MapFilter.all,
            activeBg: AppColors.forest,
            onTap: () => setState(() => _filter = MapFilter.all),
          ),
          const SizedBox(width: 8),
          _PillFilter(
            label: 'Plastic & Mixed',
            active: _filter == MapFilter.plasticMixed,
            activeBg: AppColors.forest,
            onTap: () => setState(() => _filter = MapFilter.plasticMixed),
          ),
          const SizedBox(width: 8),
          _PillFilter(
            label: 'Wet/Food',
            active: _filter == MapFilter.wetFood,
            activeBg: AppColors.forest,
            onTap: () => setState(() => _filter = MapFilter.wetFood),
          ),
          const SizedBox(width: 8),
          _PillFilter(
            label: 'E-Waste & Debris',
            active: _filter == MapFilter.eWasteDebris,
            activeBg: AppColors.forest,
            onTap: () => setState(() => _filter = MapFilter.eWasteDebris),
          ),
          const SizedBox(width: 8),
          _PillFilter(
            label: 'Verified Cleared ($clearedCount)',
            active: _filter == MapFilter.cleared,
            activeBg: AppColors.emerald,
            softMint: true,
            onTap: () => setState(() => _filter = MapFilter.cleared),
          ),
          const SizedBox(width: 8),
          _PillFilter(
            label: 'Collection Centers (Dry/Wet)',
            active: _showCenters,
            activeBg: AppColors.info,
            softBlue: true,
            onTap: () => setState(() => _showCenters = !_showCenters),
          ),
        ],
      ),
    );

    final mapCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: isWide ? 470 : 310,
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
                  initialZoom: 12.0,
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
              // Top-left cluster pill
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '$totalMerged Reports Merged | 150m Radius Spatial Cluster ●',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              // Top-right Ward Focus selector
              if (isWide)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: wardOptions.contains(_focusWard)
                            ? _focusWard
                            : 'All Bengaluru',
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        items: wardOptions
                            .map((w) => DropdownMenuItem(
                                  value: w,
                                  child: Text('FOCUS: $w'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _focusWard = val);
                          if (val == 'All Bengaluru') {
                            _mapController.move(
                                AppConstants.bengaluruCenter, 12.0);
                          } else {
                            final match = state.reports
                                .where((r) => r.wardName == val)
                                .toList();
                            if (match.isNotEmpty) {
                              _mapController.move(
                                  LatLng(match.first.lat, match.first.lng),
                                  13.8);
                              setState(() => _selectedReportId = match.first.id);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
              // Desktop floating spot card
              if (isWide && (selectedReport != null || selectedCenter != null))
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
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
            _LegendDot(color: AppColors.warning, label: 'Pending Review'),
            _LegendDot(color: AppColors.emerald, label: 'Verified Cleared'),
            _LegendDot(color: AppColors.forest, label: 'Collection Center'),
          ],
        ),
        if (!isWide && selectedReport != null) ...[
          const SizedBox(height: 14),
          _MobileSpotDetailCard(
            report: selectedReport,
            onVerify: () async {
              await showDialog<bool>(
                context: context,
                builder: (_) => VerifyProofModal(report: selectedReport),
              );
            },
            onStartDrive: () async {
              await ref.read(nagarNexProvider.notifier).createMicroDrive(
                    reportId: selectedReport.id,
                    title: 'Clean-Up Drive · ${selectedReport.placeName}',
                    wardName: selectedReport.wardName,
                    meetingPoint: selectedReport.placeName,
                    driveTime: DateTime.now().add(const Duration(days: 1)),
                  );
              if (!context.mounted) return;
              context.go('/drives');
            },
          ),
        ],
        const SizedBox(height: 16),
        // Interconnected 3 Live Ward Health Cards -> tap to open Ward Index
        _WardHealthStrip(
          wardStats: wardStats,
          onSelectWard: (w) {
            final match = state.reports
                .where((r) => r.wardName == w.wardName)
                .toList();
            if (match.isNotEmpty) {
              _mapController.move(LatLng(match.first.lat, match.first.lng), 13.8);
              setState(() {
                _focusWard = w.wardName;
                _selectedReportId = match.first.id;
              });
            }
          },
          onOpenWardIndex: () => context.go('/ward-index'),
        ),
        if (!isWide && state.rectifiedReports.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MobileVerifiedProofCard(
            report: state.rectifiedReports.first,
            onViewBoard: () => context.go('/board'),
          ),
        ],
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 15-Second Citizen Intake Card -> Tap to Capture
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
                    child: Text(
                      '⚡ 15-Second Citizen Intake',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Instant AI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Snap photo on-site. Automatic geo-tagging, EXIF stripping, face/plate masking, and waste category classification.',
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
                  _MiniInfoChip(label: 'GPS ±10m Precision'),
                  _MiniInfoChip(label: 'Auto-Blur Faces & Plates'),
                  _MiniInfoChip(label: 'Public EXIF Stripped'),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => context.go('/intake'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 24, color: AppColors.inkMuted),
                      SizedBox(height: 6),
                      Text(
                        'Tap to Capture or Upload Evidence',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'JPEG, WebP, PNG • Auto-Clustered <=150m',
                        style: TextStyle(
                            fontSize: 10.5, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/intake'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
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
            const Expanded(
              child: Text(
                '● Ward Live Incidents',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _focusWard = 'All Bengaluru';
                _filter = MapFilter.all;
              }),
              child: Text(
                'View All (${state.reports.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                padding: const EdgeInsets.all(14),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCleared
                                ? AppColors.emeraldMint.withValues(alpha: 0.45)
                                : (isOverdue || r.isRecurring
                                    ? AppColors.dangerSoft
                                    : AppColors.surfaceMuted),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCleared
                                ? '● Verified Restored'
                                : (isOverdue
                                    ? '● Overdue SLA'
                                    : '● Verification Queue'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCleared
                                  ? AppColors.forest
                                  : (isOverdue || r.isRecurring
                                      ? AppColors.danger
                                      : AppColors.inkSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.wardName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        Text(
                          '${r.reportCount}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            ref
                                .read(nagarNexProvider.notifier)
                                .toggleFollowReport(r.id);
                          },
                          tooltip: state.myReportIds.contains(r.id)
                              ? 'Tracking Updates'
                              : 'Follow Updates',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            state.myReportIds.contains(r.id)
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            size: 16,
                            color: state.myReportIds.contains(r.id)
                                ? AppColors.forest
                                : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                      '${r.wasteType} • ${r.severity} Severity • ${(r.aiConfidence * 100).round()}% AI Match',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          isCleared
                              ? 'Verified by ${r.verifyVotes} Citizens'
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
                        if (isCleared)
                          TextButton(
                            onPressed: () => context.go('/board'),
                            child: const Text(
                              'View Before/After Log →',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                          )
                        else if (r.isRecurring)
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
                              backgroundColor: AppColors.forest,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.groups_outlined, size: 14),
                            label: const Text('Start Clean-Up Drive',
                                style: TextStyle(fontSize: 11.5)),
                          )
                        else
                          OutlinedButton(
                            onPressed: () async {
                              await showDialog<bool>(
                                context: context,
                                builder: (_) => VerifyProofModal(report: r),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              'Confirm On-Site (${r.verifyVotes}/3)',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.white, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decentralized Civic Care',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Every report verified by nearby residents with Before/After proof.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD1FAE5)),
                    ),
                  ],
                ),
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              filterStrip,
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: mapCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: rightColumn),
                  ],
                )
              else
                Column(
                  children: [
                    mapCard,
                    const SizedBox(height: 18),
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

class _WardHealthStrip extends StatelessWidget {
  final List<WardStats> wardStats;
  final void Function(WardStats) onSelectWard;
  final VoidCallback onOpenWardIndex;

  const _WardHealthStrip({
    required this.wardStats,
    required this.onSelectWard,
    required this.onOpenWardIndex,
  });

  @override
  Widget build(BuildContext context) {
    final top3 = wardStats.take(3).toList();
    if (top3.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final cards = top3.map((w) {
          final healthy = w.civicScore >= 70;
          return InkWell(
            onTap: () => onSelectWard(w),
            onDoubleTap: onOpenWardIndex,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          w.wardName.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: healthy
                              ? AppColors.emeraldMint.withValues(alpha: 0.45)
                              : AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${w.clearanceRate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: healthy ? AppColors.forest : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${w.civicScore}.0',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '/ 100 Index',
                        style:
                            TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: w.civicScore / 100.0,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceMuted,
                      color: healthy ? AppColors.forest : AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onOpenWardIndex,
                    child: Text(
                      '${w.clearedSpots} Cleared · Open Ward Ledger →',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        if (wide) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        }
        return Column(
          children: cards
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MobileSpotDetailCard extends StatelessWidget {
  final WasteReport report;
  final VoidCallback onVerify;
  final VoidCallback onStartDrive;

  const _MobileSpotDetailCard({
    required this.report,
    required this.onVerify,
    required this.onStartDrive,
  });

  @override
  Widget build(BuildContext context) {
    final cleared = report.status == ReportStatus.verifiedCleared;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  report.placeName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: cleared ? AppColors.emeraldSoft : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  cleared ? '● Verified Cleared' : '● Active Blackspot',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: cleared ? AppColors.forest : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${report.wardName} • ${report.reportCount} ${report.reportCount == 1 ? "Report" : "Reports"} Merged',
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniAuditTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Volume & Type',
                  value: report.wasteType,
                  sub: '${(report.aiConfidence * 100).round()}% Conf.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniAuditTile(
                  icon: Icons.schedule_rounded,
                  title: 'Citizen SLA',
                  value: cleared
                      ? report.clearanceDurationLabel
                      : GeoUtils.formatSlaRemaining(report.slaDeadline),
                  sub: '150m cluster',
                ),
              ),
            ],
          ),
          if (!cleared) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onVerify,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Verify Fix →',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: onStartDrive,
                  tooltip: 'Start Clean-Up Drive',
                  icon: const Icon(Icons.group_add_outlined),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileVerifiedProofCard extends StatelessWidget {
  final WasteReport report;
  final VoidCallback onViewBoard;

  const _MobileVerifiedProofCard({
    required this.report,
    required this.onViewBoard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.verified_outlined,
                  size: 18, color: AppColors.forest),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Community Verified Proof',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewBoard,
                child: const Text(
                  'View Board →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${report.placeName} • ${report.verifyVotes} Neighbours confirmed clearance',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _MiniAuditTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String sub;

  const _MiniAuditTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.forest),
              const SizedBox(width: 4),
              Text(title,
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.inkMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          Text(sub,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.emeraldDark,
                  fontWeight: FontWeight.w600)),
        ],
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
          Row(
            children: [
              Expanded(
                child: Text(
                  report.isRecurring
                      ? '● REPEAT CHRONIC BLACKSPOT'
                      : '● ACTIVE CLUSTER',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: report.isRecurring ? AppColors.danger : AppColors.forest,
                  ),
                ),
              ),
              Text(
                '${(report.aiConfidence * 100).round()}% Match',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emeraldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
            '${report.wardName} • ${report.wasteType} • ${report.reportCount} Merged',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  cleared
                      ? 'Verified Cleared ✓'
                      : GeoUtils.formatSlaRemaining(report.slaDeadline),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: cleared ? AppColors.emeraldDark : AppColors.danger,
                  ),
                ),
              ),
              if (!cleared)
                FilledButton(
                  onPressed: onVerify,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Verify Fix →',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
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
