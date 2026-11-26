import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/waste_report.dart';
import '../services/app_state.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nagarNexProvider);
    final clearedCount = state.reports
        .where((r) => r.status == ReportStatus.verifiedCleared)
        .length;
    final totalMergedReports =
        state.reports.fold<int>(0, (sum, r) => sum + r.reportCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Top Nav
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.recycling_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'DEMO DATA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/board'),
                  child: const Text(
                    'Roadside Board',
                    style: TextStyle(
                      color: AppColors.inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => context.go('/map'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Launch App'),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.emerald),
                        ),
                        child: const Text(
                          'BENGALURU · PUBLIC & MUNICIPAL WASTE ACCOUNTABILITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Turn street garbage reports into\nverified, visible clearances.',
                        style: TextStyle(
                          fontSize: 40,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 680,
                        child: Text(
                          'NagarNex is an independent citizen-verified waste accountability platform for Bengaluru. It clusters duplicate reports within 150m into blackspots, requires GPS-matched Before/After proof to close tickets, powers 1-click clean-up micro-drives, and publishes rectified streets on a public QR board.',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.go('/map'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text(
                              'Explore Live Bengaluru Map',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/intake'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text(
                              'Report Waste in 15s',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/board'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: const Text(
                              'Roadside Rectified Board',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),
                      // Metrics strip
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 700;
                          final cards = [
                            _MetricCard(
                              label: 'Merged Citizen Reports',
                              value: '$totalMergedReports',
                              sub: 'Clustered into ${state.reports.length} spots (Demo)',
                            ),
                            _MetricCard(
                              label: 'Verified Cleared Spots',
                              value: '$clearedCount',
                              sub: 'Before/After GPS proofed (Demo)',
                            ),
                            _MetricCard(
                              label: 'Active Micro-Drives',
                              value: '${state.drives.length}',
                              sub: '1-Click community clean-ups',
                            ),
                            _MetricCard(
                              label: 'Collection Hubs Mapped',
                              value: '${state.centers.length}',
                              sub: 'Dry, Wet & E-Waste drop points',
                            ),
                          ];
                          if (wide) {
                            return Row(
                              children: cards
                                  .map((c) => Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 12),
                                          child: c,
                                        ),
                                      ))
                                  .toList(),
                            );
                          }
                          return Column(
                            children: cards
                                .map((c) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: c,
                                    ))
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 40),
                      const Text(
                        '5-Step Accountability Loop',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: const [
                          _WorkflowCard(
                            step: '01',
                            title: '15-Second AI Intake',
                            desc:
                                'Capture photo + GPS. Vision AI tags waste type & severity, strips EXIF metadata, and flags faces/plates.',
                          ),
                          _WorkflowCard(
                            step: '02',
                            title: '150m Blackspot Clustering',
                            desc:
                                'Nearby duplicate reports merge into one cluster with repeat recurrence alerts instead of ticket spam.',
                          ),
                          _WorkflowCard(
                            step: '03',
                            title: '1-Click Micro-Drives',
                            desc:
                                'Overdue or recurring blackspots trigger citizen clean-up drives with live volunteer RSVP counts.',
                          ),
                          _WorkflowCard(
                            step: '04',
                            title: 'Before / After Proof',
                            desc:
                                'Spots cannot close on a status toggle alone — GPS-matched After photos & citizen consensus are required.',
                          ),
                          _WorkflowCard(
                            step: '05',
                            title: 'Roadside QR Leaderboard',
                            desc:
                                'Numbered rectified Bengaluru streets, clearance times, and Ward Improvement Scores displayed publicly.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Compliance Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: const Text(
              AppConstants.disclaimerText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.emeraldDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  final String step;
  final String title;
  final String desc;

  const _WorkflowCard({
    required this.step,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 336,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.emeraldDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
