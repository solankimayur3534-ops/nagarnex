import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/geo_utils.dart';
import '../models/citizen_profile.dart';
import '../models/collection_center.dart';
import '../models/micro_drive.dart';
import '../models/waste_report.dart';
import 'supabase_service.dart';

class NagarNexState {
  final List<WasteReport> reports;
  final List<CollectionCenter> centers;
  final List<MicroDrive> drives;
  final CitizenProfile profile;
  final Map<String, Uint8List> localPhotoCache;
  final bool isLoading;

  const NagarNexState({
    required this.reports,
    required this.centers,
    required this.drives,
    required this.profile,
    this.localPhotoCache = const {},
    this.isLoading = false,
  });

  NagarNexState copyWith({
    List<WasteReport>? reports,
    List<CollectionCenter>? centers,
    List<MicroDrive>? drives,
    CitizenProfile? profile,
    Map<String, Uint8List>? localPhotoCache,
    bool? isLoading,
  }) {
    return NagarNexState(
      reports: reports ?? this.reports,
      centers: centers ?? this.centers,
      drives: drives ?? this.drives,
      profile: profile ?? this.profile,
      localPhotoCache: localPhotoCache ?? this.localPhotoCache,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<WasteReport> get rectifiedReports {
    final list = reports
        .where((r) => r.status == ReportStatus.verifiedCleared)
        .toList();
    list.sort((a, b) => (b.resolvedAt ?? b.createdAt)
        .compareTo(a.resolvedAt ?? a.createdAt));
    return list;
  }

  List<WardStats> get wardStats => SupabaseService.computeWardStats(reports);
}

class NagarNexNotifier extends Notifier<NagarNexState> {
  @override
  NagarNexState build() {
    Future.microtask(_loadInitial);
    return NagarNexState(
      reports: SupabaseService.seedWasteReports(),
      centers: SupabaseService.seedCollectionCenters(),
      drives: SupabaseService.seedMicroDrives(),
      profile: SupabaseService.seedCitizenProfile(),
      isLoading: AppConstants.hasSupabaseConfig,
    );
  }

  Future<void> _loadInitial() async {
    if (!AppConstants.hasSupabaseConfig) return;
    final reports = await SupabaseService.fetchWasteReports();
    final centers = await SupabaseService.fetchCollectionCenters();
    final drives = await SupabaseService.fetchMicroDrives();

    CitizenProfile profile = state.profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      var cid = prefs.getString('nagarnex_citizen_id');
      if (cid == null || cid.isEmpty) {
        cid = const Uuid().v4();
        await prefs.setString('nagarnex_citizen_id', cid);
      }
      final remote = await SupabaseService.fetchOrCreateCitizenProfile(
        profileId: cid,
        displayName: prefs.getString('nagarnex_citizen_name') ??
            'Bengaluru Citizen',
        wardName: prefs.getString('nagarnex_citizen_ward') ??
            'Ward 151 Koramangala',
      );
      if (remote != null) profile = remote;
    } catch (_) {}

    state = state.copyWith(
      reports: reports,
      centers: centers,
      drives: drives,
      profile: profile,
      isLoading: false,
    );
  }

  Future<void> updateCitizenIdentity({
    required String displayName,
    required String wardName,
  }) async {
    final updated = state.profile.copyWith(
      displayName: displayName.trim().isEmpty
          ? state.profile.displayName
          : displayName.trim(),
      wardName: wardName,
    );
    state = state.copyWith(profile: updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nagarnex_citizen_name', updated.displayName);
      await prefs.setString('nagarnex_citizen_ward', updated.wardName);
    } catch (_) {}
    await SupabaseService.upsertCitizenProfile(updated);
  }

  /// Submits a new AI-classified waste report. Automatically merges into an
  /// existing blackspot cluster if within 150m and matching [wasteType].
  /// Returns `(merged: bool, report: WasteReport)`.
  Future<({bool merged, WasteReport report})> submitWasteReport({
    required String wardName,
    required String placeName,
    required double lat,
    required double lng,
    required String wasteType,
    required String severity,
    required double aiConfidence,
    required Uint8List photoBytes,
  }) async {
    final existing = GeoUtils.findMatchingCluster(
      reports: state.reports,
      point: LatLng(lat, lng),
      wasteType: wasteType,
    );

    if (existing != null) {
      final newCount = existing.reportCount + 1;
      final updated = existing.copyWith(
        reportCount: newCount,
        isRecurring:
            existing.isRecurring || newCount >= AppConstants.recurringThresholdCount,
      );
      final nextReports = state.reports
          .map((r) => r.id == existing.id ? updated : r)
          .toList();
      state = state.copyWith(
        reports: nextReports,
        profile: state.profile.copyWith(
          civicPoints: state.profile.civicPoints + 15,
        ),
      );
      await SupabaseService.updateClusterMerge(updated);
      await SupabaseService.upsertCitizenProfile(state.profile);
      return (merged: true, report: updated);
    }

    final id = 'rep-${DateTime.now().millisecondsSinceEpoch}';
    final uploadedUrl = await SupabaseService.uploadPhotoBytes(
      bytes: photoBytes,
      fileName: 'before_$id.png',
    );
    final photoKey = uploadedUrl ?? 'local://before/$id';

    final newReport = WasteReport(
      id: id,
      wardName: wardName,
      placeName: placeName,
      lat: lat,
      lng: lng,
      wasteType: wasteType,
      severity: severity,
      aiConfidence: aiConfidence,
      status: ReportStatus.open,
      reportCount: 1,
      isRecurring: false,
      beforePhotoUrl: photoKey,
      verifyVotes: 0,
      slaDeadline: DateTime.now().add(const Duration(hours: 24)),
      isDemo: !AppConstants.hasSupabaseConfig,
      createdAt: DateTime.now(),
    );

    final nextCache = Map<String, Uint8List>.from(state.localPhotoCache)
      ..[photoKey] = photoBytes;

    state = state.copyWith(
      reports: [newReport, ...state.reports],
      localPhotoCache: nextCache,
      profile: state.profile.copyWith(
        civicPoints: state.profile.civicPoints + 25,
      ),
    );

    await SupabaseService.insertWasteReport(newReport);
    await SupabaseService.upsertCitizenProfile(state.profile);
    return (merged: false, report: newReport);
  }

  /// Submits an "After" clearance photo + citizen confirmation vote.
  /// Transitions to `verifiedCleared` once consensus threshold is met
  /// (or immediately in demo mode / when >=3 votes).
  Future<WasteReport> submitVerification({
    required WasteReport report,
    required Uint8List afterPhotoBytes,
    required bool markClearedNow,
  }) async {
    final uploadedUrl = await SupabaseService.uploadPhotoBytes(
      bytes: afterPhotoBytes,
      fileName: 'after_${report.id}.png',
    );
    final afterKey = uploadedUrl ?? 'local://after/${report.id}';
    final nextVotes = report.verifyVotes + 1;
    final isCleared =
        markClearedNow || nextVotes >= AppConstants.requiredVerifyVotes;

    final updated = report.copyWith(
      afterPhotoUrl: afterKey,
      verifyVotes: nextVotes,
      status: isCleared
          ? ReportStatus.verifiedCleared
          : ReportStatus.pendingVerification,
      resolvedAt: isCleared ? DateTime.now() : null,
    );

    final nextCache = Map<String, Uint8List>.from(state.localPhotoCache)
      ..[afterKey] = afterPhotoBytes;

    state = state.copyWith(
      reports: state.reports
          .map((r) => r.id == report.id ? updated : r)
          .toList(),
      localPhotoCache: nextCache,
      profile: state.profile.copyWith(
        consensusVotes: state.profile.consensusVotes + 1,
        verifiedFixes: isCleared
            ? state.profile.verifiedFixes + 1
            : state.profile.verifiedFixes,
        civicPoints: state.profile.civicPoints + (isCleared ? 40 : 20),
      ),
    );

    await SupabaseService.updateVerification(updated);
    await SupabaseService.upsertCitizenProfile(state.profile);
    return updated;
  }

  Future<MicroDrive> createMicroDrive({
    String? reportId,
    required String title,
    required String wardName,
    required String meetingPoint,
    required DateTime driveTime,
  }) async {
    final drive = MicroDrive(
      id: 'drive-${DateTime.now().millisecondsSinceEpoch}',
      reportId: reportId,
      title: title,
      wardName: wardName,
      meetingPoint: meetingPoint,
      driveTime: driveTime,
      rsvpCount: 1,
      isDemo: !AppConstants.hasSupabaseConfig,
      hasJoined: true,
    );
    state = state.copyWith(
      drives: [drive, ...state.drives],
      profile: state.profile.copyWith(
        drivesJoined: state.profile.drivesJoined + 1,
        civicPoints: state.profile.civicPoints + 30,
      ),
    );
    await SupabaseService.insertMicroDrive(drive);
    return drive;
  }

  Future<void> toggleDriveRsvp(MicroDrive drive) async {
    final joining = !drive.hasJoined;
    final updated = drive.copyWith(
      hasJoined: joining,
      rsvpCount: joining
          ? drive.rsvpCount + 1
          : (drive.rsvpCount > 0 ? drive.rsvpCount - 1 : 0),
    );
    state = state.copyWith(
      drives: state.drives
          .map((d) => d.id == drive.id ? updated : d)
          .toList(),
      profile: state.profile.copyWith(
        drivesJoined: joining
            ? state.profile.drivesJoined + 1
            : (state.profile.drivesJoined > 0
                ? state.profile.drivesJoined - 1
                : 0),
        civicPoints: joining
            ? state.profile.civicPoints + 15
            : (state.profile.civicPoints >= 15
                ? state.profile.civicPoints - 15
                : 0),
      ),
    );
    await SupabaseService.updateDriveRsvp(updated);
    await SupabaseService.upsertCitizenProfile(state.profile);
  }
}

final nagarNexProvider =
    NotifierProvider<NagarNexNotifier, NagarNexState>(NagarNexNotifier.new);
