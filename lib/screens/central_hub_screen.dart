import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/geo_utils.dart';
import '../models/waste_report.dart';
import '../services/app_state.dart';

enum CentralFilter { all, l3Escalated, open, solved }

class CentralHubScreen extends ConsumerStatefulWidget {
  const CentralHubScreen({super.key});

  @override
  ConsumerState<CentralHubScreen> createState() => _CentralHubScreenState();
}

class _CentralHubScreenState extends ConsumerState<CentralHubScreen> {
  CentralFilter _filter = CentralFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nagarNexProvider);
    final reports = state.reports;

    final openCount =
        reports.where((r) => r.status == ReportStatus.open).length;
    final l3Count = reports
        .where((r) => r.escalationTier == 'L3 Central Command')
        .length;
    final pendingCount = reports
        .where((r) => r.status == ReportStatus.pendingVerification)
        .length;
    final solvedCount =
        reports.where((r) => r.status == ReportStatus.verifiedCleared).length;

    final filtered = reports.where((r) {
      switch (_filter) {
        case CentralFilter.all:
          return true;
        case CentralFilter.l3Escalated:
          return r.escalationTier == 'L3 Central Command';
        case CentralFilter.open:
          return r.status == ReportStatus.open;
        case CentralFilter.solved:
          return r.status == ReportStatus.verifiedCleared;
      }
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Centralized Responsibility & Escalation Hub',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Active Role: ${state.adminRole} • City: ${state.currentCity} • Central SLA & Ward Ownership',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PolicyPill(
                          label: state.enforceCameraOnly
                              ? 'Camera: Enforced ✓'
                              : 'Camera: Flexible',
                          active: state.enforceCameraOnly,
                        ),
                        _PolicyPill(
                          label: state.enforceGpsOnly
                              ? 'GPS: Enforced ✓'
                              : 'GPS: Flexible',
                          active: state.enforceGpsOnly,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 KPI Cards
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HubStatCard(
                    label: 'Open Blackspots',
                    value: '$openCount',
                    color: AppColors.warning,
                  ),
                  _HubStatCard(
                    label: 'L3 Central Escalations',
                    value: '$l3Count',
                    color: AppColors.danger,
                  ),
                  _HubStatCard(
                    label: 'Pending Verification',
                    value: '$pendingCount',
                    color: AppColors.info,
                  ),
                  _HubStatCard(
                    label: 'Solved & Verified',
                    value: '$solvedCount',
                    color: AppColors.emeraldDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filters
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('All (${reports.length})'),
                    selected: _filter == CentralFilter.all,
                    selectedColor: AppColors.forest,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filter == CentralFilter.all
                          ? Colors.white
                          : AppColors.ink,
                    ),
                    onSelected: (_) =>
                        setState(() => _filter = CentralFilter.all),
                  ),
                  ChoiceChip(
                    label: Text('L3 Escalated ($l3Count)'),
                    selected: _filter == CentralFilter.l3Escalated,
                    selectedColor: AppColors.danger,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filter == CentralFilter.l3Escalated
                          ? Colors.white
                          : AppColors.ink,
                    ),
                    onSelected: (_) =>
                        setState(() => _filter = CentralFilter.l3Escalated),
                  ),
                  ChoiceChip(
                    label: Text('Open ($openCount)'),
                    selected: _filter == CentralFilter.open,
                    selectedColor: AppColors.forest,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filter == CentralFilter.open
                          ? Colors.white
                          : AppColors.ink,
                    ),
                    onSelected: (_) =>
                        setState(() => _filter = CentralFilter.open),
                  ),
                  ChoiceChip(
                    label: Text('Solved ($solvedCount)'),
                    selected: _filter == CentralFilter.solved,
                    selectedColor: AppColors.emeraldDark,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filter == CentralFilter.solved
                          ? Colors.white
                          : AppColors.ink,
                    ),
                    onSelected: (_) =>
                        setState(() => _filter = CentralFilter.solved),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Responsibility Matrix List
              ...filtered.map((r) {
                final tier = r.escalationTier;
                final isL3 = tier == 'L3 Central Command';
                final isSolved = r.status == ReportStatus.verifiedCleared;
                final assigned = state.assignedHandlers[r.id] ?? r.responsibleUnit;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isL3
                            ? AppColors.danger.withValues(alpha: 0.45)
                            : (isSolved ? AppColors.emerald : AppColors.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${r.placeName} · ${r.wardName}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSolved
                                    ? AppColors.emeraldSoft
                                    : (isL3
                                        ? AppColors.dangerSoft
                                        : AppColors.warningSoft),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                tier,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSolved
                                      ? AppColors.forest
                                      : (isL3
                                          ? AppColors.danger
                                          : AppColors.warning),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Responsible Owner: $assigned',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${r.wasteType} • ${r.reportCount} merged reports • ${GeoUtils.formatSlaRemaining(r.slaDeadline)} • ${GeoUtils.formatReportedTimestamp(r.createdAt)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!isSolved)
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  ref
                                      .read(nagarNexProvider.notifier)
                                      .assignResponsibility(
                                        r.id,
                                        'Dispatched · Field Clean-Up Crew',
                                      );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.emeraldSoft,
                                  foregroundColor: AppColors.forest,
                                ),
                                icon: const Icon(Icons.assignment_turned_in_outlined,
                                    size: 16),
                                label: const Text('Assign Crew',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            if (!isSolved)
                              OutlinedButton.icon(
                                onPressed: () {
                                  ref
                                      .read(nagarNexProvider.notifier)
                                      .assignResponsibility(
                                        r.id,
                                        'Escalated · Central Accountability Desk',
                                      );
                                },
                                icon: const Icon(Icons.priority_high_rounded,
                                    size: 16),
                                label: const Text('Escalate',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            TextButton.icon(
                              onPressed: () => context.go('/map'),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: const Text('Inspect on Map',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyPill extends StatelessWidget {
  final String label;
  final bool active;
  const _PolicyPill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.emeraldSoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AppColors.emerald : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.forest : AppColors.inkSecondary,
        ),
      ),
    );
  }
}

class _HubStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HubStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
