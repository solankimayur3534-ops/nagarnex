import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/fullscreen_helper.dart';
import '../models/waste_report.dart';
import '../services/app_state.dart';
import '../widgets/animated_logo.dart';
import '../widgets/judge_tour.dart';
import '../widgets/permission_gate_dialog.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  bool _gateShowing = false;

  void _maybeShowPermissionGate(bool required) {
    if (!required || _gateShowing || !mounted) return;
    _gateShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _gateShowing = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PermissionGateDialog(),
      );
      _gateShowing = false;
    });
  }

  void _openJudgeTour() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => const JudgeTourOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      nagarNexProvider.select((s) => s.permissionGateRequired),
      (_, next) => _maybeShowPermissionGate(next),
    );
    final state = ref.watch(nagarNexProvider);
    if (state.permissionGateRequired) {
      _maybeShowPermissionGate(true);
    }
    final clearedCount = state.reports
        .where((r) => r.status == ReportStatus.verifiedCleared)
        .length;
    final totalMergedReports =
        state.reports.fold<int>(0, (sum, r) => sum + r.reportCount);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 960;
    final isMobile = width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF041F17),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed background image covering the entire viewport
          Image.asset(
            'assets/images/hero_bg.jpg',
            fit: BoxFit.cover,
            cacheWidth: 960,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          // Deep 3D forest-emerald atmospheric scrim for razor-sharp readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF041F17).withValues(alpha: 0.78),
                  const Color(0xFF064E3B).withValues(alpha: 0.74),
                  const Color(0xFF021610).withValues(alpha: 0.92),
                ],
              ),
            ),
          ),

          // Main scrollable content + glass top bar + footer
          Column(
            children: [
              // Frosted Glass Top Nav
              ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 24, vertical: 12),
                    child: Row(
                      children: [
                        const AnimatedLogo(size: 36, darkBackground: true),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            AppConstants.appName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isMobile ? 17 : 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              state.currentCity,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emeraldMint,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (isWide) ...[
                          TextButton(
                            onPressed: () => context.go('/ward-index'),
                            child: const Text(
                              'Ward Index',
                              style: TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/drives'),
                            child: const Text(
                              'Micro-Drives',
                              style: TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (!isMobile) ...[
                          TextButton(
                            onPressed: () => context.go('/board'),
                            child: const Text(
                              'Roadside Board',
                              style: TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openJudgeTour,
                            icon: const Icon(Icons.play_circle_outline_rounded,
                                size: 16, color: AppColors.emeraldMint),
                            label: const Text(
                              'Judge Demo',
                              style: TextStyle(
                                color: AppColors.emeraldMint,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            enterFullscreenIfMobile();
                            context.go('/map');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.emeraldMint,
                            foregroundColor: const Color(0xFF041F17),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Launch App',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Split: Left Copy + Right 3D Floating Civic Card
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _HeroCopy(
                                    onMap: () => context.go('/map'),
                                    onIntake: () => context.go('/intake'),
                                    onBoard: () => context.go('/board'),
                                    onDemo: _openJudgeTour,
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  flex: 4,
                                  child: _Hero3DPreviewCard(
                                    totalMerged: totalMergedReports,
                                    clearedCount: clearedCount,
                                    drivesCount: state.drives.length,
                                    onOpenDrives: () => context.go('/drives'),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _HeroCopy(
                              onMap: () => context.go('/map'),
                              onIntake: () => context.go('/intake'),
                              onBoard: () => context.go('/board'),
                              onDemo: _openJudgeTour,
                            ),
                            const SizedBox(height: 24),
                            _Hero3DPreviewCard(
                              totalMerged: totalMergedReports,
                              clearedCount: clearedCount,
                              drivesCount: state.drives.length,
                              onOpenDrives: () => context.go('/drives'),
                            ),
                          ],

                          const SizedBox(height: 36),
                          // 3D Glassmorphic KPI Strip
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 700;
                              final cards = [
                                _GlassMetricCard(
                                  icon: Icons.layers_outlined,
                                  label: 'Merged Citizen Reports',
                                  value: '$totalMergedReports',
                                  sub:
                                      'Clustered into ${state.reports.length} spots',
                                  onTap: () => context.go('/map'),
                                ),
                                _GlassMetricCard(
                                  icon: Icons.verified_outlined,
                                  label: 'Verified Cleared Spots',
                                  value: '$clearedCount',
                                  sub: 'Before/After GPS proofed',
                                  onTap: () => context.go('/board'),
                                ),
                                _GlassMetricCard(
                                  icon: Icons.groups_outlined,
                                  label: 'Active Micro-Drives',
                                  value: '${state.drives.length}',
                                  sub: '1-Click community clean-ups',
                                  onTap: () => context.go('/drives'),
                                ),
                                _GlassMetricCard(
                                  icon: Icons.recycling_rounded,
                                  label: 'Collection Hubs Mapped',
                                  value: '${state.centers.length}',
                                  sub: 'Dry, Wet & E-Waste drop points',
                                  onTap: () => context.go('/map'),
                                ),
                              ];
                              if (wide) {
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: cards
                                        .map((c) => Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 14),
                                                child: c,
                                              ),
                                            ))
                                        .toList(),
                                  ),
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

                          const SizedBox(height: 44),
                          const Text(
                            '5-Step Citizen Accountability Loop',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: const [
                              _GlassWorkflowCard(
                                step: '01',
                                title: '15-Second AI Intake',
                                desc:
                                    'Capture photo + GPS. Vision AI tags waste type & severity, strips EXIF metadata, and flags faces/plates.',
                              ),
                              _GlassWorkflowCard(
                                step: '02',
                                title: '150m Blackspot Clustering',
                                desc:
                                    'Nearby duplicate reports merge into one cluster with repeat recurrence alerts instead of ticket spam.',
                              ),
                              _GlassWorkflowCard(
                                step: '03',
                                title: '1-Click Micro-Drives',
                                desc:
                                    'Overdue or recurring blackspots trigger citizen clean-up drives with live volunteer RSVP counts.',
                              ),
                              _GlassWorkflowCard(
                                step: '04',
                                title: 'Before / After Proof',
                                desc:
                                    'Spots cannot close on a status toggle alone — GPS-matched After photos & citizen consensus are required.',
                              ),
                              _GlassWorkflowCard(
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

              // Live Civic Ticker Strip (isolated widget to avoid full-screen repaints)
              _LiveCivicTicker(
                items: [
                  '● LIVE  ·  $totalMergedReports merged citizen reports across ${state.reports.length} Bengaluru spots',
                  '● VERIFIED  ·  $clearedCount blackspots cleared with GPS Before/After proof',
                  '● ACTION  ·  ${state.drives.length} active community clean-up micro-drives open for RSVP',
                ],
              ),

              // Compliance Footer with Animated Logo
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF021610).withValues(alpha: 0.9),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AnimatedLogo(size: 24, darkBackground: true),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        AppConstants.disclaimerText,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
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
  }
}

class _LiveCivicTicker extends StatefulWidget {
  final List<String> items;
  const _LiveCivicTicker({required this.items});

  @override
  State<_LiveCivicTicker> createState() => _LiveCivicTickerState();
}

class _LiveCivicTickerState extends State<_LiveCivicTicker> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _idx++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMsg = widget.items[_idx % widget.items.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.emerald.withValues(alpha: 0.16),
        border: Border(
          top: BorderSide(color: AppColors.emeraldMint.withValues(alpha: 0.25)),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Text(
          currentMsg,
          key: ValueKey(currentMsg),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.emeraldMint,
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final VoidCallback onMap;
  final VoidCallback onIntake;
  final VoidCallback onBoard;
  final VoidCallback onDemo;

  const _HeroCopy({
    required this.onMap,
    required this.onIntake,
    required this.onBoard,
    required this.onDemo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.emeraldMint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.emeraldMint.withValues(alpha: 0.45),
            ),
          ),
          child: const Text(
            '● BENGALURU · CITIZEN-VERIFIED WASTE ACCOUNTABILITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.emeraldMint,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Turn street garbage reports into verified, visible clearances.',
          style: TextStyle(
            fontSize: 42,
            height: 1.12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'NagarNex unites citizens across Bengaluru neighborhoods to cluster duplicate reports within 150m, verify clean-ups with GPS-matched Before/After proof, mobilize 1-click micro-drives, and spotlight rectified streets.',
          style: TextStyle(
            fontSize: 16,
            height: 1.55,
            color: Color(0xFFE2E8F0),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onMap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emeraldMint,
                foregroundColor: const Color(0xFF041F17),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 8,
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text(
                'Explore Live Bengaluru Map',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onIntake,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text(
                'Report Waste in 15s',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onBoard,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text(
                'Roadside Board',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onDemo,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emeraldMint,
                side: BorderSide(
                    color: AppColors.emeraldMint.withValues(alpha: 0.55)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text(
                '4-Step Judge Tour',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Hero3DPreviewCard extends StatelessWidget {
  final int totalMerged;
  final int clearedCount;
  final int drivesCount;
  final VoidCallback onOpenDrives;

  const _Hero3DPreviewCard({
    required this.totalMerged,
    required this.clearedCount,
    required this.drivesCount,
    required this.onOpenDrives,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(-0.04)
        ..rotateX(0.02),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldMint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LIVE CIVIC PULSE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF041F17),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.public_rounded,
                        color: AppColors.emeraldMint, size: 18),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Citizen Action Across Bengaluru',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Neighbors verifying street clearances & hosting clean-up sprints.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 16),
                _PulseRow(
                  icon: Icons.people_outline_rounded,
                  label: 'Active Community Clean-Up Drives',
                  val: '$drivesCount Live',
                ),
                const SizedBox(height: 10),
                _PulseRow(
                  icon: Icons.verified_rounded,
                  label: 'GPS Before/After Verified Fixes',
                  val: '$clearedCount Cleared',
                ),
                const SizedBox(height: 10),
                _PulseRow(
                  icon: Icons.hub_outlined,
                  label: '150m Clustered Citizen Reports',
                  val: '$totalMerged Merged',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenDrives,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF041F17),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.groups_rounded, size: 18),
                    label: const Text(
                      'Join a Clean-Up Micro-Drive →',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

class _PulseRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String val;

  const _PulseRow({
    required this.icon,
    required this.label,
    required this.val,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.emeraldMint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
            ),
          ),
          Text(
            val,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.emeraldMint,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  const _GlassMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.emeraldMint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedVal, _) {
                    return Text(
                      int.tryParse(value) != null ? '$animatedVal' : value,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.emeraldMint,
                    fontWeight: FontWeight.w600,
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

class _GlassWorkflowCard extends StatelessWidget {
  final String step;
  final String title;
  final String desc;

  const _GlassWorkflowCard({
    required this.step,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 348,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldMint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFFCBD5E1),
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
