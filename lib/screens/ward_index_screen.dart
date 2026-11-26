import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/waste_report.dart';
import '../services/app_state.dart';
import '../services/supabase_service.dart';

enum WardFilter { all, high, actionReq }

class WardIndexScreen extends ConsumerStatefulWidget {
  const WardIndexScreen({super.key});

  @override
  ConsumerState<WardIndexScreen> createState() => _WardIndexScreenState();
}

class _WardIndexScreenState extends ConsumerState<WardIndexScreen> {
  WardFilter _filter = WardFilter.all;
  String _search = '';

  String _buildCsv(List<WardStats> stats) {
    final buf = StringBuffer(
      'Ward,Civic_Score,Total_Spots,Cleared,Active_Blackspots,Recurring_Spots,Clearance_Rate_Pct,Avg_Clearance_Hours\n',
    );
    for (final s in stats) {
      buf.writeln(
        '"${s.wardName}",${s.civicScore},${s.totalSpots},${s.clearedSpots},${s.activeBlackspots},${s.recurringSpots},${s.clearanceRate.toStringAsFixed(1)},${s.avgClearanceHours.toStringAsFixed(1)}',
      );
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nagarNexProvider);
    final allStats = state.wardStats;
    final isWide = MediaQuery.sizeOf(context).width >= 960;

    final filtered = allStats.where((w) {
      if (_search.isNotEmpty &&
          !w.wardName.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      switch (_filter) {
        case WardFilter.all:
          return true;
        case WardFilter.high:
          return w.civicScore >= 75;
        case WardFilter.actionReq:
          return w.civicScore < 75 || w.recurringSpots > 0;
      }
    }).toList();

    final avgRate = allStats.isEmpty
        ? 0.0
        : allStats.fold<double>(0, (s, w) => s + w.clearanceRate) /
            allStats.length;
    final avgHours = allStats.isEmpty
        ? 0.0
        : allStats.fold<double>(0, (s, w) => s + w.avgClearanceHours) /
            allStats.length;
    final repeatSites =
        state.reports.where((r) => r.isRecurring).length;

    final repeatReports = state.reports
        .where((r) => r.isRecurring)
        .toList()
      ..sort((a, b) => b.reportCount.compareTo(a.reportCount));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPEN CIVIC INTELLIGENCE LEDGER • YEAR 2026',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Bengaluru Ward Waste Index & Clearance Ledger',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Real-time waste clearance performance, resolution speed, and recurring blackspots across monitored Bengaluru wards.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(
                              text: AppConstants.liveBoardUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Ward Index link copied!')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.share_outlined, size: 16),
                        label: const Text('Share Ward Card'),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          final csv = _buildCsv(allStats);
                          Clipboard.setData(ClipboardData(text: csv));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Ward Index CSV copied to clipboard!'),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text(
                            'Export Ward CSV (Open Data CC-BY-4.0)'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4 KPI Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final kpis = [
                    _WardKpiCard(
                      title: 'Active Monitored',
                      badge: 'LIVE',
                      value: '${allStats.length} / 198',
                      sub: '● 100% Monitored by Citizen Reports',
                      valueColor: AppColors.ink,
                      subColor: AppColors.emeraldDark,
                    ),
                    _WardKpiCard(
                      title: 'Avg Clearance Rate',
                      badge: 'VERIFIED',
                      value: '${avgRate.toStringAsFixed(1)}%',
                      sub: 'Photo-Verified Consensus',
                      valueColor: AppColors.emeraldDark,
                      subColor: AppColors.inkMuted,
                    ),
                    _WardKpiCard(
                      title: 'Avg Clearance Time',
                      badge: 'REALTIME',
                      value: '${avgHours.toStringAsFixed(1)}h',
                      sub: 'Citizen Target <24h',
                      valueColor: AppColors.ink,
                      subColor: AppColors.inkMuted,
                    ),
                    _WardKpiCard(
                      title: 'Repeat Blackspots',
                      badge: 'ACTION REQ',
                      badgeDanger: true,
                      value: '${repeatSites.toString().padLeft(2, '0')} Sites',
                      sub: 'Chronic sites requiring micro-drives',
                      valueColor: AppColors.danger,
                      subColor: AppColors.inkMuted,
                    ),
                  ];
                  if (wide) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: kpis
                            .map((c) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: c,
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  }
                  return Column(
                    children: kpis
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: c,
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Ledger Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            _SegPill(
                              label: 'All Wards (${allStats.length})',
                              active: _filter == WardFilter.all,
                              onTap: () =>
                                  setState(() => _filter = WardFilter.all),
                            ),
                            _SegPill(
                              label: 'High Improvement',
                              active: _filter == WardFilter.high,
                              onTap: () =>
                                  setState(() => _filter = WardFilter.high),
                            ),
                            _SegPill(
                              label: 'Action Required',
                              active: _filter == WardFilter.actionReq,
                              onTap: () => setState(
                                  () => _filter = WardFilter.actionReq),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              hintText: 'Search ward by name or number...',
                              hintStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(filtered.length, (i) {
                      final w = filtered[i];
                      final rank = (i + 1).toString().padLeft(2, '0');
                      final isNeedsAction = w.civicScore < 60;
                      final statusLabel = w.civicScore >= 85
                          ? 'Exemplary'
                          : (w.civicScore >= 70
                              ? 'Healthy'
                              : (w.civicScore >= 55
                                  ? 'Good'
                                  : 'Needs Action'));

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: isNeedsAction
                                  ? AppColors.dangerSoft.withValues(alpha: 0.45)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: const Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    '#$rank',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        w.wardName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      Text(
                                        '${w.clearedSpots} of ${w.totalSpots} spots cleared',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Text(
                                        '${w.civicScore}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: isNeedsAction
                                              ? AppColors.danger
                                              : AppColors.emeraldDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isNeedsAction
                                              ? AppColors.dangerSoft
                                              : AppColors.emeraldSoft,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: isNeedsAction
                                                ? AppColors.danger
                                                : AppColors.emeraldDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isWide) ...[
                                  Expanded(
                                    child: Text(
                                      '${w.clearanceRate.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${w.avgClearanceHours.toStringAsFixed(1)}h avg',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                                TextButton(
                                  onPressed: () => context.go('/map'),
                                  child: const Text(
                                    'Inspect →',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (w.recurringSpots > 0 && isNeedsAction)
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 18, color: AppColors.danger),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'BLACKSPOT RECURRENCE ALERT: ${w.recurringSpots} repeat dumping hotspot(s) detected within 150m in ${w.wardName}.',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => context.go('/drives'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.danger,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Join Escalation',
                                        style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom 2-column analytics
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _CategoryMixCard(reports: state.reports)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _TopRepeatCard(
                      repeats: repeatReports,
                      onLaunchDrive: () => context.go('/drives'),
                    )),
                  ],
                )
              else ...[
                _CategoryMixCard(reports: state.reports),
                const SizedBox(height: 16),
                _TopRepeatCard(
                  repeats: repeatReports,
                  onLaunchDrive: () => context.go('/drives'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WardKpiCard extends StatelessWidget {
  final String title;
  final String badge;
  final bool badgeDanger;
  final String value;
  final String sub;
  final Color valueColor;
  final Color subColor;

  const _WardKpiCard({
    required this.title,
    required this.badge,
    this.badgeDanger = false,
    required this.value,
    required this.sub,
    required this.valueColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeDanger
                      ? AppColors.dangerSoft
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: badgeDanger ? AppColors.danger : AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.forest : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.forest : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryMixCard extends StatelessWidget {
  final List<WasteReport> reports;
  const _CategoryMixCard({required this.reports});

  @override
  Widget build(BuildContext context) {
    final total = reports.isEmpty ? 1 : reports.length;
    final wet = reports.where((r) => r.wasteType == 'Wet/Food').length;
    final plastic = reports.where((r) => r.wasteType == 'Plastic').length;
    final debris = reports.where((r) => r.wasteType == 'Mixed/Debris').length;
    final ewaste = reports
        .where((r) => r.wasteType == 'E-Waste' || r.wasteType == 'Glass')
        .length;

    return Container(
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
                  'AI Waste Category Mix',
                  style: TextStyle(
                    fontSize: 16,
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'AI Live',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: [
                      (wet / total, AppColors.forest),
                      (plastic / total, AppColors.emeraldMint),
                      (debris / total, AppColors.inkMuted),
                      (ewaste / total, AppColors.info),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${reports.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const Text(
                          'CLUSTERS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _MixRow('Wet / Food Waste',
                        '${(wet / total * 100).round()}%', AppColors.forest),
                    _MixRow(
                        'Plastic & Packaging',
                        '${(plastic / total * 100).round()}%',
                        AppColors.emerald),
                    _MixRow('Mixed / Debris',
                        '${(debris / total * 100).round()}%', AppColors.inkMuted),
                    _MixRow('E-Waste & Glass',
                        '${(ewaste / total * 100).round()}%', AppColors.info),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MixRow extends StatelessWidget {
  final String label;
  final String pct;
  final Color dot;
  const _MixRow(this.label, this.pct, this.dot);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.inkSecondary)),
          ),
          Text(pct,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _TopRepeatCard extends StatelessWidget {
  final List<WasteReport> repeats;
  final VoidCallback onLaunchDrive;

  const _TopRepeatCard({
    required this.repeats,
    required this.onLaunchDrive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  'Top Repeat Blackspots',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Priority 1',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...repeats.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.placeName,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink)),
                            Text(r.wardName,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${r.reportCount}x Reports',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLaunchDrive,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.groups_outlined, size: 17),
              label: const Text('Launch Community Micro-Drive',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments;
  _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    double startAngle = -math.pi / 2;

    for (final (fraction, color) in segments) {
      if (fraction <= 0) continue;
      final sweep = fraction * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => false;
}
