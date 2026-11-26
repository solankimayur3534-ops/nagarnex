import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../services/app_state.dart';
import 'passport_drawer.dart';

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

class NavShell extends ConsumerWidget {
  final String currentRoute;
  final Widget child;

  const NavShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;
    final profile = ref.watch(nagarNexProvider).profile;

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
        titleSpacing: 16,
        title: Row(
          children: [
            InkWell(
              onTap: () => context.go('/'),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.forest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.recycling_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
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
                      child: const Text(
                        'Bengaluru',
                        style: TextStyle(
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
          FilledButton.icon(
            onPressed: () => context.go('/intake'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
            label: Text(
              isDesktop ? 'Report Waste' : 'Report',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              tooltip: 'Citizen Impact Passport',
              icon: const CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.ink,
                child: Icon(Icons.person_outline_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: child),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'NagarNex — Independent Citizen Initiative. Not affiliated with any government authority.',
                    style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                  ),
                ),
                if (isDesktop)
                  const Text(
                    'Privacy & EXIF Policy  •  Open Civic Data (2026)',
                    style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                  ),
              ],
            ),
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
