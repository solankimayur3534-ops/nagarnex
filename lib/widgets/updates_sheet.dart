import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/geo_utils.dart';
import '../models/waste_report.dart';
import '../services/app_state.dart';

class UpdatesSheet extends ConsumerStatefulWidget {
  const UpdatesSheet({super.key});

  @override
  ConsumerState<UpdatesSheet> createState() => _UpdatesSheetState();
}

class _UpdatesSheetState extends ConsumerState<UpdatesSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showAllQueries = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nagarNexProvider);
    final query = _searchCtrl.text.trim().toLowerCase();

    final baseList = _showAllQueries
        ? state.reports
        : state.reports.where((r) => state.myReportIds.contains(r.id)).toList();

    final filtered = query.isEmpty
        ? baseList
        : baseList.where((r) {
            return r.placeName.toLowerCase().contains(query) ||
                r.wardName.toLowerCase().contains(query) ||
                r.id.toLowerCase().contains(query);
          }).toList();

    final solvedCount = baseList
        .where((r) => r.status == ReportStatus.verifiedCleared)
        .length;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: AppColors.forest,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Query Status & Problem Updates',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Solved: $solvedCount / ${baseList.length} • Live SLA & Before/After proof',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
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
              Row(
                children: [
                  ChoiceChip(
                    label: Text('My Queries (${state.myReportIds.length})'),
                    selected: !_showAllQueries,
                    selectedColor: AppColors.forest,
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: !_showAllQueries ? Colors.white : AppColors.ink,
                    ),
                    onSelected: (_) => setState(() => _showAllQueries = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('All City Queries (${state.reports.length})'),
                    selected: _showAllQueries,
                    selectedColor: AppColors.forest,
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _showAllQueries ? Colors.white : AppColors.ink,
                    ),
                    onSelected: (_) => setState(() => _showAllQueries = true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by place, ward, or report ID...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined,
                            size: 36, color: AppColors.inkMuted),
                        const SizedBox(height: 8),
                        Text(
                          _showAllQueries
                              ? 'No matching queries found.'
                              : 'No tracked queries yet.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Submit a waste photo or tap "All City Queries" above to track any spot.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go('/intake');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                          label: const Text('Report Waste in 15s'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = filtered[i];
                      final isCleared =
                          r.status == ReportStatus.verifiedCleared;
                      final isPending =
                          r.status == ReportStatus.pendingVerification;
                      final step = isCleared ? 3 : (isPending ? 2 : 1);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCleared
                              ? AppColors.emeraldSoft.withValues(alpha: 0.35)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCleared
                                ? AppColors.emerald
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.placeName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isCleared
                                        ? AppColors.emeraldSoft
                                        : (isPending
                                            ? AppColors.warningSoft
                                            : AppColors.dangerSoft),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isCleared
                                        ? 'SOLVED ✓'
                                        : (isPending
                                            ? 'VERIFYING (${r.verifyVotes}/3)'
                                            : 'OPEN · NOT SOLVED'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: isCleared
                                          ? AppColors.forest
                                          : (isPending
                                              ? AppColors.warning
                                              : AppColors.danger),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.wardName} • ${r.wasteType} • ${r.reportCount} merged • ${GeoUtils.formatReportedTimestamp(r.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.inkSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 3-Step Visual Progress Bar
                            Row(
                              children: [
                                _StepPill(label: '1. Reported', done: step >= 1),
                                const SizedBox(width: 4),
                                _StepPill(label: '2. Review', done: step >= 2),
                                const SizedBox(width: 4),
                                _StepPill(label: '3. Solved ✓', done: step >= 3),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    context.go('/map');
                                  },
                                  icon: const Icon(Icons.map_outlined, size: 15),
                                  label: const Text('Track on Map',
                                      style: TextStyle(fontSize: 12)),
                                ),
                                if (isCleared)
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      context.go('/board');
                                    },
                                    icon: const Icon(Icons.verified_outlined,
                                        size: 15),
                                    label: const Text('View Solved Proof',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool done;

  const _StepPill({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: done ? AppColors.forest : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: done ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
