import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/fullscreen_helper.dart';
import '../services/app_state.dart';
import 'animated_logo.dart';
import 'passport_drawer.dart';
import 'permission_gate_dialog.dart';
import 'updates_sheet.dart';

class NavItemSpec {
  final String label;
  final String route;
  final IconData icon;

  const NavItemSpec({
    required this.label,
    required this.route,
    required this.icon,
  });
}

const List<NavItemSpec> kAppNavItems = [
  NavItemSpec(label: 'Live Map', route: '/map', icon: Icons.map_outlined),
  NavItemSpec(
      label: 'Ward Index', route: '/ward-index', icon: Icons.analytics_outlined),
  NavItemSpec(
      label: 'Micro-Drives', route: '/drives', icon: Icons.groups_outlined),
  NavItemSpec(
      label: 'Rectified Board',
      route: '/board',
      icon: Icons.qr_code_2_rounded),
];

class NavShell extends ConsumerStatefulWidget {
  final String currentRoute;
  final Widget child;

  const NavShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> {
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

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      nagarNexProvider.select((s) => s.permissionGateRequired),
      (_, next) => _maybeShowPermissionGate(next),
    );
    final appState = ref.watch(nagarNexProvider);
    if (appState.permissionGateRequired) {
      _maybeShowPermissionGate(true);
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;
    final isMobile = width < 600;
    final profile = appState.profile;
    final currentRoute = widget.currentRoute;
    final child = widget.child;

    int selectedIndex =
        kAppNavItems.indexWhere((item) => item.route == currentRoute);
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: const PassportDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        titleSpacing: isMobile ? 8 : 16,
        title: Row(
          children: [
            Flexible(
              child: InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedLogo(size: 32),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        AppConstants.appName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          appState.currentCity,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: kAppNavItems.map((item) {
                          final active = item.route == currentRoute;
                          return InkWell(
                            onTap: () => context.go(item.route),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.forest
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? Colors.white
                                      : AppColors.inkSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
        actions: [
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.emeraldMint.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 14, color: AppColors.forest),
                  const SizedBox(width: 3),
                  Text(
                    '${profile.civicPoints}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () => context.go('/intake'),
            tooltip: 'Report Waste',
            padding: isMobile ? const EdgeInsets.all(4) : null,
            constraints: isMobile ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle_outline_rounded,
                      size: 14, color: Colors.white),
                  if (!isMobile) ...[
                    const SizedBox(width: 4),
                    Text(
                      isDesktop ? 'Report Waste' : 'Report',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: isMobile ? 0 : 6),
          Builder(
            builder: (ctx) {
              final navState = ref.watch(nagarNexProvider);
              final badgeCount = navState.unreadUpdates > 0
                  ? navState.unreadUpdates
                  : navState.myReportIds.length;
              return IconButton(
                onPressed: () {
                  ref.read(nagarNexProvider.notifier).markUpdatesRead();
                  showDialog<void>(
                    context: ctx,
                    builder: (_) => const UpdatesSheet(),
                  );
                },
                tooltip: 'My Problem Updates',
                padding: isMobile ? const EdgeInsets.all(4) : null,
                constraints: isMobile ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
                icon: Badge(
                  isLabelVisible: badgeCount > 0,
                  backgroundColor: navState.unreadUpdates > 0
                      ? AppColors.danger
                      : AppColors.emerald,
                  label: Text('$badgeCount'),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.ink,
                    size: 21,
                  ),
                ),
              );
            },
          ),
          Builder(
            builder: (ctx) => IconButton(
              onPressed: toggleFullscreen,
              tooltip: 'Toggle Fullscreen',
              padding: isMobile ? const EdgeInsets.all(4) : null,
              constraints: isMobile ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              icon: const Icon(
                Icons.fullscreen_rounded,
                color: AppColors.ink,
                size: 22,
              ),
            ),
          ),
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              tooltip: 'Citizen Impact Passport',
              padding: isMobile ? const EdgeInsets.all(4) : null,
              constraints: isMobile ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              icon: const CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.ink,
                child: Icon(Icons.person_outline_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 4 : 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/app_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.72),
                  AppColors.background.withValues(alpha: 0.80),
                  Colors.white.withValues(alpha: 0.84),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Expanded(child: child),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.90),
                  border:
                      const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AnimatedLogo(size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'NagarNex • Role: ${appState.adminRole} • Managed by Municipal & National Civic Grid',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inkMuted),
                      ),
                    ),
                    if (isDesktop)
                      const Text(
                        'Privacy & EXIF Policy  •  Open Civic Data (2026)',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.emeraldSoft,
              onDestinationSelected: (idx) =>
                  context.go(kAppNavItems[idx].route),
              destinations: kAppNavItems
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon, color: AppColors.inkSecondary),
                      selectedIcon: Icon(item.icon, color: AppColors.forest),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
