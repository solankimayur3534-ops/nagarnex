import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../services/app_state.dart';
import 'rank_badge.dart';

class PassportDrawer extends ConsumerWidget {
  const PassportDrawer({super.key});

  Future<bool> _promptAdminUnlock(
    BuildContext context,
    WidgetRef ref, {
    String? reason,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminUnlockDialog(
        reason: reason,
        onVerify: (password) => ref
            .read(nagarNexProvider.notifier)
            .verifyAndUnlockAdmin(password),
      ),
    );
    return result ?? false;
  }

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
                      key: ValueKey(
                          'role_${appState.adminRole}_${appState.isAdminUnlocked}'),
                      initialValue: appState.adminRole,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Active Management Level',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Citizen',
                            child: Text('Citizen (Report & Verify)',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'Municipal Ward Admin',
                            child: Text('Municipal Ward Admin (ULB)',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'National Civic Admin',
                            child: Text('National Civic Admin (Policy)',
                                overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) async {
                        if (v == null || v == appState.adminRole) return;
                        if (v != 'Citizen' && !appState.isAdminUnlocked) {
                          final ok = await _promptAdminUnlock(
                            context,
                            ref,
                            reason:
                                'Enter the admin password to switch into $v.',
                          );
                          if (!ok) return;
                        }
                        ref.read(nagarNexProvider.notifier).setAdminRole(v);
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/central');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.hub_outlined, size: 16),
                        label: const Text('Open Central Command Hub →',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/bi-dashboard');
                        },
                        icon: const Icon(Icons.bar_chart_rounded, size: 16),
                        label: const Text('Open Power BI Dashboard →',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Admin Policy Controls (Supabase)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (appState.isAdminUnlocked) {
                        ref.read(nagarNexProvider.notifier).lockAdmin();
                      } else {
                        _promptAdminUnlock(context, ref);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: appState.isAdminUnlocked
                            ? AppColors.emeraldSoft
                            : AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: appState.isAdminUnlocked
                              ? AppColors.emerald
                              : AppColors.warning,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            appState.isAdminUnlocked
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            size: 12,
                            color: appState.isAdminUnlocked
                                ? AppColors.forest
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            appState.isAdminUnlocked ? 'Lock' : 'Locked',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: appState.isAdminUnlocked
                                  ? AppColors.forest
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      secondary: Icon(
                        appState.isAdminUnlocked
                            ? Icons.verified_user_outlined
                            : Icons.lock_outline_rounded,
                        size: 18,
                        color: appState.isAdminUnlocked
                            ? AppColors.forest
                            : AppColors.inkMuted,
                      ),
                      title: const Text('Enforce Camera Only',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        appState.isAdminUnlocked
                            ? 'Unlocked · Synced via Supabase'
                            : 'Password required to modify',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      value: appState.enforceCameraOnly,
                      activeThumbColor: AppColors.forest,
                      onChanged: (v) async {
                        if (!appState.isAdminUnlocked) {
                          final ok = await _promptAdminUnlock(
                            context,
                            ref,
                            reason:
                                'Enter the admin password to change Enforce Camera Only.',
                          );
                          if (!ok) return;
                        }
                        await ref
                            .read(nagarNexProvider.notifier)
                            .setAdminEnforcement(enforceCameraOnly: v);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    SwitchListTile(
                      dense: true,
                      secondary: Icon(
                        appState.isAdminUnlocked
                            ? Icons.verified_user_outlined
                            : Icons.lock_outline_rounded,
                        size: 18,
                        color: appState.isAdminUnlocked
                            ? AppColors.forest
                            : AppColors.inkMuted,
                      ),
                      title: const Text('Enforce Live GPS Only',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        appState.isAdminUnlocked
                            ? 'Unlocked · Synced via Supabase'
                            : 'Password required to modify',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      value: appState.enforceGpsOnly,
                      activeThumbColor: AppColors.forest,
                      onChanged: (v) async {
                        if (!appState.isAdminUnlocked) {
                          final ok = await _promptAdminUnlock(
                            context,
                            ref,
                            reason:
                                'Enter the admin password to change Enforce Live GPS Only.',
                          );
                          if (!ok) return;
                        }
                        await ref
                            .read(nagarNexProvider.notifier)
                            .setAdminEnforcement(enforceGpsOnly: v);
                      },
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

class _AdminUnlockDialog extends StatefulWidget {
  final String? reason;
  final bool Function(String password) onVerify;

  const _AdminUnlockDialog({
    required this.onVerify,
    this.reason,
  });

  @override
  State<_AdminUnlockDialog> createState() => _AdminUnlockDialogState();
}

class _AdminUnlockDialogState extends State<_AdminUnlockDialog> {
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _errorText;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  void _attemptUnlock() {
    if (widget.onVerify(_passCtrl.text)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorText = 'Incorrect admin password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.forest, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Admin Authentication Required',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.reason ??
                  'Enter the admin password to unlock Governance roles and Supabase Policy Controls.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _attemptUnlock(),
              decoration: InputDecoration(
                labelText: 'Admin Password',
                border: const OutlineInputBorder(),
                errorText: _errorText,
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _attemptUnlock,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.lock_open_rounded, size: 16),
          label: const Text('Unlock Admin'),
        ),
      ],
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
