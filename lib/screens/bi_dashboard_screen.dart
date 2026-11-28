import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/waste_report.dart';
import '../services/app_state.dart';

class BiDashboardScreen extends ConsumerStatefulWidget {
  const BiDashboardScreen({super.key});

  @override
  ConsumerState<BiDashboardScreen> createState() => _BiDashboardScreenState();
}

class _BiDashboardScreenState extends ConsumerState<BiDashboardScreen> {
  String _selectedWard = 'All Wards';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  static const Color _biGold = Color(0xFFF2C811);
  static const Color _biGoldDark = Color(0xFF926E00);

  static const List<_TrendPoint> _demoTrend = [
    _TrendPoint('Nov 22', 12, 5),
    _TrendPoint('Nov 23', 18, 8),
    _TrendPoint('Nov 24', 15, 7),
    _TrendPoint('Nov 25', 24, 11),
    _TrendPoint('Nov 26', 21, 10),
    _TrendPoint('Nov 27', 28, 12),
    _TrendPoint('Nov 28', 36, 13),
  ];

  String _statusLabel(ReportStatus status) {
    switch (status) {
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.pendingVerification:
        return 'Pending Verification';
      case ReportStatus.verifiedCleared:
        return 'Verified Cleared';
    }
  }

  String _buildPowerBiCsv(List<WasteReport> reports) {
    final buf = StringBuffer(
      'id,ward_name,place_name,lat,lng,waste_type,severity,ai_confidence,status,report_count,is_recurring,verify_votes,is_demo,data_note\n',
    );
    for (final r in reports) {
      final note = r.isDemo
          ? 'Dummy / Demo Data (Hackathon Time Constraint)'
          : 'Live In-Session Report';
      buf.writeln(
        '"${r.id}","${r.wardName}","${r.placeName}",${r.lat},${r.lng},"${r.wasteType}","${r.severity}",${r.aiConfidence.toStringAsFixed(2)},"${_statusLabel(r.status)}",${r.reportCount},${r.isRecurring},${r.verifyVotes},${r.isDemo},"$note"',
      );
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nagarNexProvider);
    final allReports = state.reports;
    final wards = <String>{'All Wards', ...allReports.map((r) => r.wardName)}
        .toList();
    if (!wards.contains(_selectedWard)) {
      _selectedWard = 'All Wards';
    }

    final filtered = allReports.where((r) {
      if (_selectedWard != 'All Wards' && r.wardName != _selectedWard) {
        return false;
      }
      if (_selectedCategory != 'All' && r.wasteType != _selectedCategory) {
        return false;
      }
      if (_selectedStatus != 'All' && _statusLabel(r.status) != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    final totalClusters = filtered.length;
    final totalMerged = filtered.fold<int>(0, (s, r) => s + r.reportCount);
    final clearedCount = filtered
        .where((r) => r.status == ReportStatus.verifiedCleared)
        .length;
    final clearanceRate =
        totalClusters == 0 ? 0.0 : (clearedCount / totalClusters) * 100.0;
    final recurringCount = filtered.where((r) => r.isRecurring).length;

    final resolvedReports =
        filtered.where((r) => r.resolvedAt != null).toList();
    final avgClearHours = resolvedReports.isEmpty
        ? 0.0
        : resolvedReports.fold<double>(
              0,
              (s, r) =>
                  s +
                  r.resolvedAt!.difference(r.createdAt).inMinutes.abs() / 60.0,
            ) /
            resolvedReports.length;

    final Map<String, int> categoryCounts = {};
    for (final r in filtered) {
      categoryCounts[r.wasteType] =
          (categoryCounts[r.wasteType] ?? 0) + r.reportCount;
    }

    final isWide = MediaQuery.sizeOf(context).width >= 960;

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
                spacing: 14,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _biGold.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _biGold.withValues(alpha: 0.85)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bar_chart_rounded,
                                    size: 14, color: _biGoldDark),
                                SizedBox(width: 5),
                                Text(
                                  'POWER BI CIVIC ANALYTICS',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _biGoldDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Dummy / Demo Data Mode',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bengaluru Waste Accountability BI Dashboard',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Interactive Power BI-style civic analytics slicing ward clearance rates, repeat blackspots, and AI category mix.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.go('/ward-index'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.table_chart_outlined, size: 16),
                        label: const Text('Ward Ledger'),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          final csv = _buildPowerBiCsv(filtered);
                          Clipboard.setData(ClipboardData(text: csv));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Power BI CSV dataset copied to clipboard (is_demo tagged)!'),
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
                        label: const Text('Export Power BI CSV'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Explicit Dummy / Demo Data Disclosure Banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.45)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo / Dummy Dataset Notice: Due to limited hackathon time, pre-populated Bengaluru sample records and 7-day trend metrics are shown for demonstration (is_demo = true) alongside any live reports created in this session. Schema-matched CSV exports are ready for Power BI Desktop.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Slicer Panel
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Interactive Report Slicers',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedWard = 'All Wards';
                              _selectedCategory = 'All';
                              _selectedStatus = 'All';
                            });
                          },
                          child: const Text('Reset Slicers',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('bi_ward_$_selectedWard'),
                            initialValue: _selectedWard,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ward Slicer',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: wards
                                .map((w) => DropdownMenuItem(
                                      value: w,
                                      child: Text(w,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 12.5)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedWard = v);
                            },
                          ),
                        ),
                        ...[
                          'All',
                          'Plastic',
                          'Wet/Food',
                          'Glass',
                          'E-Waste',
                          'Mixed/Debris',
                        ].map((cat) {
                          final active = _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: active,
                            selectedColor: AppColors.forest,
                            backgroundColor: AppColors.surfaceMuted,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : AppColors.ink,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                          );
                        }),
                        ...[
                          'All',
                          'Open',
                          'Pending Verification',
                          'Verified Cleared',
                        ].map((st) {
                          final active = _selectedStatus == st;
                          return FilterChip(
                            label: Text('Status: $st'),
                            selected: active,
                            selectedColor: AppColors.emeraldSoft,
                            checkmarkColor: AppColors.forest,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AppColors.forest
                                  : AppColors.inkSecondary,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedStatus = st),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 Power BI KPI Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 900
                      ? 4
                      : (constraints.maxWidth >= 540 ? 2 : 1);
                  final cardW =
                      (constraints.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _BiKpiCard(
                        width: cardW,
                        title: 'Merged Reports',
                        value: '$totalMerged',
                        subtitle: '$totalClusters active hotspot clusters',
                        accent: AppColors.forest,
                        badge: 'VOLUME',
                      ),
                      _BiKpiCard(
                        width: cardW,
                        title: 'Verified Clearance Rate',
                        value: '${clearanceRate.toStringAsFixed(1)}%',
                        subtitle: '$clearedCount of $totalClusters clusters cleared',
                        accent: AppColors.emeraldDark,
                        badge: 'VERIFIED',
                      ),
                      _BiKpiCard(
                        width: cardW,
                        title: 'Avg Clearance Time',
                        value: resolvedReports.isEmpty
                            ? '—'
                            : '${avgClearHours.toStringAsFixed(1)}h',
                        subtitle: 'Citizen SLA target < 24.0h',
                        accent: AppColors.info,
                        badge: 'VELOCITY',
                      ),
                      _BiKpiCard(
                        width: cardW,
                        title: 'Repeat Blackspots',
                        value: '$recurringCount',
                        subtitle: '5+ merged reports in 150 m',
                        accent: AppColors.danger,
                        badge: 'PRIORITY',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Row 1: Trend + Ward Performance
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildTrendCard()),
                    const SizedBox(width: 16),
                    Expanded(
                        flex: 5,
                        child: _buildCategoryVolumeCard(
                            categoryCounts, totalMerged)),
                  ],
                )
              else ...[
                _buildTrendCard(),
                const SizedBox(height: 16),
                _buildCategoryVolumeCard(categoryCounts, totalMerged),
              ],
              const SizedBox(height: 18),

              // Ward Performance Matrix + Hotspot Drill-Down Table
              _buildWardMatrixCard(state.wardStats),
              const SizedBox(height: 18),
              _buildHotspotTableCard(filtered),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Intake vs. Verified Clearances',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Simulated 7-day sample time-series (Demo / Dummy Data)',
                      style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'DEMO SERIES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _LegendDot(color: AppColors.forest, label: 'Merged Reports'),
              _LegendDot(color: AppColors.emerald, label: 'Verified Clearances'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 205,
            width: double.infinity,
            child: CustomPaint(
              painter: _BiTrendChartPainter(points: _demoTrend),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryVolumeCard(Map<String, int> counts, int totalMerged) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      AppColors.forest,
      AppColors.emerald,
      AppColors.info,
      AppColors.warning,
      AppColors.danger,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Waste Volume by AI Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Share of merged reports matching slicer selection',
            style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No records match current slicers.',
                    style: TextStyle(color: AppColors.inkMuted)),
              ),
            )
          else
            ...List.generate(entries.length, (i) {
              final e = entries[i];
              final pct = totalMerged == 0 ? 0.0 : e.value / totalMerged;
              final barColor = colors[i % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${e.value} (${(pct * 100).round()}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceMuted,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildWardMatrixCard(List wardStats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ward Clearance Performance Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Clearance %, active blackspots, and civic index across Bengaluru wards',
            style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 14),
          ...wardStats.map((w) {
            final pct = (w.clearanceRate / 100.0).clamp(0.0, 1.0);
            final healthy = w.civicScore >= 75;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          w.wardName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${w.clearanceRate.round()}% • ${w.avgClearanceHours.toStringAsFixed(0)}h',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        healthy ? AppColors.emerald : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHotspotTableCard(List<WasteReport> filtered) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hotspot Cluster Detail Table',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(AppColors.surfaceMuted),
              columns: const [
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Ward')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Severity')),
                DataColumn(label: Text('Merged')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Source')),
              ],
              rows: filtered.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r.placeName,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(r.wardName)),
                    DataCell(Text(r.wasteType)),
                    DataCell(Text(r.severity)),
                    DataCell(Text('${r.reportCount}')),
                    DataCell(Text(_statusLabel(r.status))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: r.isDemo
                              ? AppColors.warningSoft
                              : AppColors.emeraldSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          r.isDemo ? 'Demo Data' : 'Live',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: r.isDemo
                                ? AppColors.warning
                                : AppColors.forest,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiKpiCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final String badge;

  const _BiKpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
          ),
        ],
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

class _TrendPoint {
  final String label;
  final int mergedReports;
  final int clearedCount;
  const _TrendPoint(this.label, this.mergedReports, this.clearedCount);
}

class _BiTrendChartPainter extends CustomPainter {
  final List<_TrendPoint> points;
  _BiTrendChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const bottomPad = 24.0;
    const topPad = 14.0;
    final chartH = size.height - bottomPad - topPad;
    final maxVal = points
        .map((p) => math.max(p.mergedReports, p.clearedCount))
        .fold<int>(1, math.max)
        .toDouble();

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int g = 0; g <= 3; g++) {
      final y = topPad + chartH * (g / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slotW = size.width / points.length;
    final barW = math.min(18.0, slotW * 0.28);
    final mergedPaint = Paint()..color = AppColors.forest;
    final clearedPaint = Paint()..color = AppColors.emerald;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = slotW * i + slotW / 2;

      final h1 = (p.mergedReports / maxVal) * chartH;
      final h2 = (p.clearedCount / maxVal) * chartH;

      final r1 = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW - 2, topPad + chartH - h1, barW, h1),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      final r2 = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx + 2, topPad + chartH - h2, barW, h2),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(r1, mergedPaint);
      canvas.drawRRect(r2, clearedPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: p.label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - bottomPad + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BiTrendChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
