import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../services/app_state.dart';
import 'rank_badge.dart';

class PassportDrawer extends ConsumerWidget {
  const PassportDrawer({super.key});

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentWard,
  ) async {
    final nameCtrl = TextEditingController(text: currentName);
    String selectedWard = AppConstants.bengaluruPresets
            .any((p) => p['ward'].toString() == currentWard)
        ? currentWard
        : AppConstants.bengaluruPresets[0]['ward'].toString();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Update Citizen Passport'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedWard,
                  decoration: const InputDecoration(
                    labelText: 'Home Bengaluru Ward',
                    border: OutlineInputBorder(),
                  ),
                  items: AppConstants.bengaluruPresets
                      .map((p) => DropdownMenuItem(
                            value: p['ward'].toString(),
                            child: Text(p['ward'].toString()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) selectedWard = v;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(nagarNexProvider.notifier)
                    .updateCitizenIdentity(
                      displayName: nameCtrl.text,
                      wardName: selectedWard,
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Profile'),
            ),
          ],
        ),
      );
    } finally {
      nameCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(nagarNexProvider);
    final profile = appState.profile;

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.emerald),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.wardName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showEditProfileDialog(
                      context,
                      ref,
                      profile.displayName,
                      profile.wardName,
                    ),
                    tooltip: 'Edit Name & Ward',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RankPassportCard(civicPoints: profile.civicPoints),
              const SizedBox(height: 20),
              const Text(
                'Verified Civic Contributions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _StatRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Verified Street Fixes',
                value: '${profile.verifiedFixes}',
                color: AppColors.emeraldDark,
              ),
              const SizedBox(height: 10),
              _StatRow(
                icon: Icons.groups_outlined,
                label: 'Micro-Drives Joined',
                value: '${profile.drivesJoined}',
                color: AppColors.info,
              ),
              const SizedBox(height: 10),
              _StatRow(
                icon: Icons.how_to_vote_outlined,
                label: 'Consensus Proof Votes',
                value: '${profile.consensusVotes}',
                color: AppColors.warning,
              ),
              const SizedBox(height: 18),
              const Text(
                'Governance & Admin Hierarchy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: appState.adminRole,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Active Management Level',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Citizen',
                            child: Text('Citizen (Report & Verify)')),
                        DropdownMenuItem(
                            value: 'Municipal Ward Admin',
                            child: Text('Municipal Ward Admin (BBMP / ULB)')),
                        DropdownMenuItem(
                            value: 'National Civic Admin',
                            child: Text('National Civic Admin (Super Policy)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(nagarNexProvider.notifier).setAdminRole(v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Municipal Admin: Ward SLA & Before/After clearance\n• National Admin: Global Camera/GPS rules via Supabase',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Admin Policy Controls (Supabase)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      title: const Text('Enforce Camera Only',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      value: appState.enforceCameraOnly,
                      activeThumbColor: AppColors.forest,
                      onChanged: (v) => ref
                          .read(nagarNexProvider.notifier)
                          .setAdminEnforcement(enforceCameraOnly: v),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Enforce Live GPS Only',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      value: appState.enforceGpsOnly,
                      activeThumbColor: AppColors.forest,
                      onChanged: (v) => ref
                          .read(nagarNexProvider.notifier)
                          .setAdminEnforcement(enforceGpsOnly: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Guest / Demo Mode active. No login wall required for judges or citizens.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
