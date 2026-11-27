import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../services/app_state.dart';

/// Mandatory startup permission popup shown whenever Supabase `app_settings`
/// enforces `enforce_gps_only` or `enforce_camera_only` and live browser/device
/// permissions are not yet granted. Re-appears on page refresh until granted.
class PermissionGateDialog extends ConsumerStatefulWidget {
  const PermissionGateDialog({super.key});

  @override
  ConsumerState<PermissionGateDialog> createState() =>
      _PermissionGateDialogState();
}

class _PermissionGateDialogState extends ConsumerState<PermissionGateDialog> {
  bool _busyGps = false;
  bool _busyCam = false;

  Future<void> _enableGps() async {
    setState(() => _busyGps = true);
    await ref
        .read(nagarNexProvider.notifier)
        .detectAndUpdateLocation(requestIfNeeded: true);
    if (!mounted) return;
    setState(() => _busyGps = false);
    _closeIfSatisfied();
  }

  Future<void> _enableCamera() async {
    setState(() => _busyCam = true);
    await ref.read(nagarNexProvider.notifier).requestCameraAccess();
    if (!mounted) return;
    setState(() => _busyCam = false);
    _closeIfSatisfied();
  }

  void _closeIfSatisfied() {
    final s = ref.read(nagarNexProvider);
    if (!s.permissionGateRequired && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nagarNexProvider);

    return PopScope(
      canPop: !state.permissionGateRequired,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.forest),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Required Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live verification policy is active. Enable the required device permissions below to continue with exact coordinates and live capture:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (state.enforceGpsOnly)
                _PermTile(
                  icon: Icons.my_location_rounded,
                  title: 'Live GPS Location',
                  subtitle: state.gpsPermissionGranted
                      ? 'Granted (${state.currentCity})'
                      : 'Required for exact coordinates & city detection',
                  granted: state.gpsPermissionGranted,
                  busy: _busyGps,
                  onTap: _enableGps,
                ),
              if (state.enforceGpsOnly && state.enforceCameraOnly)
                const SizedBox(height: 10),
              if (state.enforceCameraOnly)
                _PermTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Live Camera Access',
                  subtitle: state.cameraPermissionGranted
                      ? 'Granted'
                      : 'Required for authentic street waste capture',
                  granted: state.cameraPermissionGranted,
                  busy: _busyCam,
                  onTap: _enableCamera,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(nagarNexProvider.notifier)
                  .refreshPermissionsAndLocation(autoRequestIfEnforced: false);
              _closeIfSatisfied();
            },
            child: const Text('Re-check Status'),
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final bool busy;
  final VoidCallback onTap;

  const _PermTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: granted ? AppColors.emeraldSoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted ? AppColors.emerald : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : icon,
            color: granted ? AppColors.forest : AppColors.ink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!granted)
            FilledButton(
              onPressed: busy ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(busy ? '...' : 'Enable',
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
