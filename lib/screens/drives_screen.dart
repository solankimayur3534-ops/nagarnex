import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../services/app_state.dart';

class DrivesScreen extends ConsumerWidget {
  const DrivesScreen({super.key});

  Future<void> _showCreateDriveDialog(
      BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final pointCtrl = TextEditingController();
    String selectedWard = AppConstants.bengaluruPresets[0]['ward'].toString();

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Host 1-Click Clean-Up Micro-Drive'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Drive Title',
                    hintText: 'e.g. Saturday Morning Lake Edge Sweep',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedWard,
                  decoration: const InputDecoration(
                    labelText: 'Bengaluru Ward',
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
                const SizedBox(height: 12),
                TextField(
                  controller: pointCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Point',
                    hintText: 'e.g. Main Bus Stop Corner',
                    border: OutlineInputBorder(),
                  ),
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
                await ref.read(nagarNexProvider.notifier).createMicroDrive(
                      title: titleCtrl.text.trim().isEmpty
                          ? 'Citizen Clean-Up Blitz'
                          : titleCtrl.text.trim(),
                      wardName: selectedWard,
                      meetingPoint: pointCtrl.text.trim().isEmpty
                          ? 'Ward Junction'
                          : pointCtrl.text.trim(),
                      driveTime: DateTime.now().add(const Duration(days: 1)),
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
              ),
              child: const Text('Launch Drive'),
            ),
          ],
        ),
      );
    } finally {
      titleCtrl.dispose();
      pointCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nagarNexProvider);
    final drives = state.drives;
    final profile = state.profile;
    final dateFmt = DateFormat('EEE • hh:mm a');
    final isWide = MediaQuery.sizeOf(context).width >= 960;

    final leftDrives = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _FilterPill(label: 'Upcoming (${drives.length})', active: true),
                const _FilterPill(label: 'This Weekend', active: false),
                const _FilterPill(label: 'Completed', active: false),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _showCreateDriveDialog(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('+ Host Drive',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...drives.map((drive) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldMint.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '✓ Verified Community Drive',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          drive.wardName,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    drive.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Clearing chronic plastic & roadside debris blackspot. Biodegradable bags, grabbers, and gloves provided on-site.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        _MetaCol('Schedule', dateFmt.format(drive.driveTime)),
                        _MetaCol('Meeting Point', drive.meetingPoint),
                        _MetaCol(
                            'Commitment', '${drive.rsvpCount} neighbors pledged'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.forest,
                        child: Text('AM',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${drive.rsvpCount} verified neighbors joining',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => ref
                            .read(nagarNexProvider.notifier)
                            .toggleDriveRsvp(drive),
                        style: FilledButton.styleFrom(
                          backgroundColor: drive.hasJoined
                              ? AppColors.forest
                              : AppColors.emeraldDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          drive.hasJoined ? 'Joined ✓ (Attending)' : 'RSVP Spot',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );

    final rightPassport = Column(
      children: [
        Container(
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
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.forest,
                    child: Text('GC',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '${profile.civicTier} • ${profile.wardName}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CIVIC IMPACT SCORE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${profile.civicPoints} pts',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_user_rounded,
                        size: 30, color: AppColors.emerald),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PassportMiniStat(
                        '${profile.verifiedFixes}', 'Cleared Spots Verified'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PassportMiniStat(
                        '${profile.drivesJoined}', 'Clean-Up Drives Joined'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PassportMiniStat(
                        '${profile.consensusVotes}', 'Consensus Votes'),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: _PassportMiniStat('#04', 'Ward Rank'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emeraldSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Proof-of-Civic-Action Principle: Impact score is earned through verified street confirmations and clean-up participation.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.forest,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Autonomous Safety Gear Hub',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Community tool libraries hold grabbers, puncture-resistant gloves, and bio-sacks at 14 residential pickups.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldMint.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '● Hyperlocal Autonomous Action • Bengaluru 2026',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Community Clean-Up Micro-Drives',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Grassroot citizen mobilization sprints for chronic waste blackspots in Bengaluru. Powered by verifiable before-and-after proof.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isWide)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Peer Sprints',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.inkMuted),
                          ),
                          Text(
                            '${drives.length} Micro-Drives Live',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: leftDrives),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: rightPassport),
                  ],
                )
              else
                Column(
                  children: [
                    leftDrives,
                    const SizedBox(height: 16),
                    rightPassport,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  const _FilterPill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _MetaCol extends StatelessWidget {
  final String title;
  final String value;
  const _MetaCol(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
      ],
    );
  }
}

class _PassportMiniStat extends StatelessWidget {
  final String val;
  final String label;
  const _PassportMiniStat(this.val, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(val,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 10.5, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}
