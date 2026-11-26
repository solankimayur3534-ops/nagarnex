import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/citizen_profile.dart';
import '../models/collection_center.dart';
import '../models/micro_drive.dart';
import '../models/waste_report.dart';

class WardStats {
  final String wardName;
  final int totalSpots;
  final int clearedSpots;
  final int activeBlackspots;
  final int recurringSpots;
  final double clearanceRate;
  final double avgClearanceHours;
  final int civicScore;

  const WardStats({
    required this.wardName,
    required this.totalSpots,
    required this.clearedSpots,
    required this.activeBlackspots,
    required this.recurringSpots,
    required this.clearanceRate,
    required this.avgClearanceHours,
    required this.civicScore,
  });
}

class SupabaseService {
  static SupabaseClient? get _client {
    if (!AppConstants.hasSupabaseConfig) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<List<WasteReport>> fetchWasteReports() async {
    final client = _client;
    if (client == null) return seedWasteReports();

    try {
      final data = await client
          .from('waste_reports')
          .select()
          .order('created_at', ascending: false);
      final list = (data as List)
          .map((e) => WasteReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list.isEmpty ? seedWasteReports() : list;
    } catch (_) {
      return seedWasteReports();
    }
  }

  static Future<List<CollectionCenter>> fetchCollectionCenters() async {
    final client = _client;
    if (client == null) return seedCollectionCenters();

    try {
      final data = await client.from('collection_centers').select();
      final list = (data as List)
          .map((e) => CollectionCenter.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list.isEmpty ? seedCollectionCenters() : list;
    } catch (_) {
      return seedCollectionCenters();
    }
  }

  static Future<List<MicroDrive>> fetchMicroDrives() async {
    final client = _client;
    if (client == null) return seedMicroDrives();

    try {
      final data = await client
          .from('micro_drives')
          .select()
          .order('drive_time', ascending: true);
      final list = (data as List)
          .map((e) => MicroDrive.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list.isEmpty ? seedMicroDrives() : list;
    } catch (_) {
      return seedMicroDrives();
    }
  }

  static Future<String?> uploadPhotoBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      await client.storage.from('waste-photos').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      return client.storage.from('waste-photos').getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  static Future<void> insertWasteReport(WasteReport report) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('waste_reports').insert(report.toInsertJson());
    } catch (_) {}
  }

  static Future<void> updateClusterMerge(WasteReport updated) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('waste_reports').update({
        'report_count': updated.reportCount,
        'is_recurring': updated.isRecurring,
      }).eq('id', updated.id);
    } catch (_) {}
  }

  static Future<void> updateVerification(WasteReport updated) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('waste_reports').update({
        'after_photo_url': updated.afterPhotoUrl,
        'verify_votes': updated.verifyVotes,
        'status': updated.status.dbValue,
        if (updated.resolvedAt != null)
          'resolved_at': updated.resolvedAt!.toUtc().toIso8601String(),
      }).eq('id', updated.id);
    } catch (_) {}
  }

  static Future<void> insertMicroDrive(MicroDrive drive) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('micro_drives').insert(drive.toInsertJson());
    } catch (_) {}
  }

  static Future<void> updateDriveRsvp(MicroDrive drive) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from('micro_drives')
          .update({'rsvp_count': drive.rsvpCount}).eq('id', drive.id);
    } catch (_) {}
  }

  static Future<CitizenProfile?> fetchOrCreateCitizenProfile({
    required String profileId,
    required String displayName,
    required String wardName,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      final existing = await client
          .from('citizen_profiles')
          .select()
          .eq('id', profileId)
          .maybeSingle();
      if (existing != null) {
        return CitizenProfile.fromJson(Map<String, dynamic>.from(existing));
      }
      final inserted = await client
          .from('citizen_profiles')
          .insert({
            'id': profileId,
            'display_name': displayName,
            'ward_name': wardName,
            'verified_fixes': 0,
            'drives_joined': 0,
            'consensus_votes': 0,
            'civic_points': 50,
          })
          .select()
          .single();
      return CitizenProfile.fromJson(Map<String, dynamic>.from(inserted));
    } catch (_) {
      return null;
    }
  }

  static Future<void> upsertCitizenProfile(CitizenProfile profile) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('citizen_profiles').upsert({
        'id': profile.id,
        'display_name': profile.displayName,
        'ward_name': profile.wardName,
        'verified_fixes': profile.verifiedFixes,
        'drives_joined': profile.drivesJoined,
        'consensus_votes': profile.consensusVotes,
        'civic_points': profile.civicPoints,
      });
    } catch (_) {}
  }

  static Future<({bool enforceCameraOnly, bool enforceGpsOnly})>
      fetchAppSettings() async {
    final client = _client;
    if (client == null) {
      return (enforceCameraOnly: false, enforceGpsOnly: false);
    }
    try {
      final row = await client
          .from('app_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row != null) {
        return (
          enforceCameraOnly: row['enforce_camera_only'] as bool? ?? false,
          enforceGpsOnly: row['enforce_gps_only'] as bool? ?? false,
        );
      }
    } catch (_) {}
    return (enforceCameraOnly: false, enforceGpsOnly: false);
  }

  static Future<void> updateAppSettings({
    required bool enforceCameraOnly,
    required bool enforceGpsOnly,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('app_settings').upsert({
        'id': 1,
        'enforce_camera_only': enforceCameraOnly,
        'enforce_gps_only': enforceGpsOnly,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static List<WardStats> computeWardStats(List<WasteReport> reports) {
    final Map<String, List<WasteReport>> byWard = {};
    for (final r in reports) {
      byWard.putIfAbsent(r.wardName, () => []).add(r);
    }

    final stats = byWard.entries.map((entry) {
      final list = entry.value;
      final total = list.length;
      final cleared =
          list.where((r) => r.status == ReportStatus.verifiedCleared).toList();
      final active = total - cleared.length;
      final recurring = list.where((r) => r.isRecurring).length;
      final rate = total == 0 ? 0.0 : (cleared.length / total) * 100.0;

      double avgHours = 18.0;
      if (cleared.isNotEmpty) {
        final sumH = cleared.fold<double>(
          0.0,
          (acc, r) =>
              acc +
              (r.resolvedAt ?? DateTime.now())
                      .difference(r.createdAt)
                      .abs()
                      .inMinutes /
                  60.0,
        );
        avgHours = sumH / cleared.length;
      }

      // Civic Improvement Score (0-100): weighted by clearance rate, speed, low recurrence
      final speedBonus = (36.0 - avgHours.clamp(0.0, 36.0)) / 36.0 * 30.0;
      final recurrencePenalty = (recurring / total) * 15.0;
      final score =
          (rate * 0.65 + speedBonus + 10.0 - recurrencePenalty).clamp(12.0, 99.0);

      return WardStats(
        wardName: entry.key,
        totalSpots: total,
        clearedSpots: cleared.length,
        activeBlackspots: active,
        recurringSpots: recurring,
        clearanceRate: rate,
        avgClearanceHours: avgHours,
        civicScore: score.round(),
      );
    }).toList();

    stats.sort((a, b) => b.civicScore.compareTo(a.civicScore));
    return stats;
  }

  static List<WasteReport> seedWasteReports() {
    final now = DateTime.now();
    return [
      WasteReport(
        id: 'demo-bellandur-01',
        wardName: 'Ward 150 Bellandur',
        placeName: 'Bellandur Lake Service Road',
        lat: 12.9304,
        lng: 77.6784,
        wasteType: 'Mixed/Debris',
        severity: 'High',
        aiConfidence: 0.94,
        status: ReportStatus.verifiedCleared,
        reportCount: 9,
        isRecurring: true,
        beforePhotoUrl: 'demo://before/bellandur',
        afterPhotoUrl: 'demo://after/bellandur',
        verifyVotes: 4,
        slaDeadline: now.subtract(const Duration(hours: 10)),
        resolvedAt: now.subtract(const Duration(hours: 4)),
        isDemo: true,
        createdAt: now.subtract(const Duration(hours: 14)),
      ),
      WasteReport(
        id: 'demo-indiranagar-02',
        wardName: 'Ward 80 Indiranagar',
        placeName: 'Indiranagar 12th Main Corner',
        lat: 12.9718,
        lng: 77.6412,
        wasteType: 'Plastic',
        severity: 'Medium',
        aiConfidence: 0.91,
        status: ReportStatus.verifiedCleared,
        reportCount: 6,
        isRecurring: true,
        beforePhotoUrl: 'demo://before/indiranagar',
        afterPhotoUrl: 'demo://after/indiranagar',
        verifyVotes: 3,
        slaDeadline: now.subtract(const Duration(hours: 14)),
        resolvedAt: now.subtract(const Duration(hours: 9)),
        isDemo: true,
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
      WasteReport(
        id: 'demo-koramangala-03',
        wardName: 'Ward 151 Koramangala',
        placeName: 'Koramangala 80ft Road Bus Stop',
        lat: 12.9352,
        lng: 77.6245,
        wasteType: 'Wet/Food',
        severity: 'High',
        aiConfidence: 0.96,
        status: ReportStatus.open,
        reportCount: 7,
        isRecurring: true,
        beforePhotoUrl: 'demo://before/koramangala',
        verifyVotes: 0,
        slaDeadline: now.add(const Duration(hours: 5, minutes: 20)),
        isDemo: true,
        createdAt: now.subtract(const Duration(hours: 18)),
      ),
      WasteReport(
        id: 'demo-whitefield-04',
        wardName: 'Ward 84 Whitefield',
        placeName: 'ITPL Main Road Gate 2',
        lat: 12.9850,
        lng: 77.7366,
        wasteType: 'E-Waste',
        severity: 'High',
        aiConfidence: 0.89,
        status: ReportStatus.open,
        reportCount: 5,
        isRecurring: true,
        beforePhotoUrl: 'demo://before/whitefield',
        verifyVotes: 1,
        slaDeadline: now.add(const Duration(hours: 2, minutes: 15)),
        isDemo: true,
        createdAt: now.subtract(const Duration(hours: 21)),
      ),
      WasteReport(
        id: 'demo-hsr-05',
        wardName: 'Ward 174 HSR Layout',
        placeName: 'HSR Sector 2 27th Main',
        lat: 12.9121,
        lng: 77.6446,
        wasteType: 'Plastic',
        severity: 'Medium',
        aiConfidence: 0.92,
        status: ReportStatus.pendingVerification,
        reportCount: 3,
        isRecurring: false,
        beforePhotoUrl: 'demo://before/hsr',
        afterPhotoUrl: 'demo://after/hsr',
        verifyVotes: 2,
        slaDeadline: now.add(const Duration(hours: 11)),
        isDemo: true,
        createdAt: now.subtract(const Duration(hours: 13)),
      ),
      WasteReport(
        id: 'demo-jayanagar-06',
        wardName: 'Ward 169 Jayanagar',
        placeName: 'Jayanagar 4th Block Market Edge',
        lat: 12.9299,
        lng: 77.5838,
        wasteType: 'Wet/Food',
        severity: 'Low',
        aiConfidence: 0.88,
        status: ReportStatus.verifiedCleared,
        reportCount: 4,
        isRecurring: false,
        beforePhotoUrl: 'demo://before/jayanagar',
        afterPhotoUrl: 'demo://after/jayanagar',
        verifyVotes: 3,
        slaDeadline: now.subtract(const Duration(hours: 22)),
        resolvedAt: now.subtract(const Duration(hours: 18)),
        isDemo: true,
        createdAt: now.subtract(const Duration(hours: 26)),
      ),
      WasteReport(
        id: 'demo-malleswaram-07',
        wardName: 'Ward 112 Malleswaram',
        placeName: 'Sampige Road 8th Cross',
        lat: 13.0031,
        lng: 77.5643,
        wasteType: 'Glass',
        severity: 'Medium',
        aiConfidence: 0.90,
        status: ReportStatus.open,
        reportCount: 2,
        isRecurring: false,
        beforePhotoUrl: 'demo://before/malleswaram',
        verifyVotes: 0,
        slaDeadline: now.add(const Duration(hours: 18)),
        isDemo: true,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
    ];
  }

  static List<CollectionCenter> seedCollectionCenters() {
    return const [
      CollectionCenter(
        id: 'cc-bellandur',
        centerName: 'Bellandur Dry Waste Collection Centre',
        wardName: 'Ward 150 Bellandur',
        address: 'Near EcoSpace Gate, Bellandur',
        acceptedTypes: ['Dry', 'Plastic', 'E-Waste'],
        lat: 12.9279,
        lng: 77.6810,
      ),
      CollectionCenter(
        id: 'cc-indiranagar',
        centerName: 'Indiranagar Swachh Kiosk',
        wardName: 'Ward 80 Indiranagar',
        address: '100ft Rd, HAL 2nd Stage',
        acceptedTypes: ['Dry', 'Wet', 'Glass'],
        lat: 12.9784,
        lng: 77.6408,
      ),
      CollectionCenter(
        id: 'cc-koramangala',
        centerName: 'Koramangala Zero-Waste Hub',
        wardName: 'Ward 151 Koramangala',
        address: '3rd Block, Near BDA Complex',
        acceptedTypes: ['Dry', 'Wet', 'E-Waste'],
        lat: 12.9310,
        lng: 77.6288,
      ),
      CollectionCenter(
        id: 'cc-whitefield',
        centerName: 'Whitefield E-Waste & Dry Point',
        wardName: 'Ward 84 Whitefield',
        address: 'Pattandur Agrahara Main Rd',
        acceptedTypes: ['Dry', 'E-Waste'],
        lat: 12.9815,
        lng: 77.7412,
      ),
      CollectionCenter(
        id: 'cc-jayanagar',
        centerName: 'Jayanagar Civic Recovery Centre',
        wardName: 'Ward 169 Jayanagar',
        address: '9th Main, 4th Block',
        acceptedTypes: ['Dry', 'Wet', 'Glass'],
        lat: 12.9255,
        lng: 77.5862,
      ),
    ];
  }

  static List<MicroDrive> seedMicroDrives() {
    final now = DateTime.now();
    return [
      MicroDrive(
        id: 'drive-01',
        reportId: 'demo-koramangala-03',
        title: '80ft Road Bus Stop Morning Blitz',
        wardName: 'Ward 151 Koramangala',
        meetingPoint: 'Koramangala 80ft Rd Bus Shelter',
        driveTime: now.add(const Duration(days: 1, hours: 8)),
        rsvpCount: 14,
        isDemo: true,
      ),
      MicroDrive(
        id: 'drive-02',
        reportId: 'demo-whitefield-04',
        title: 'ITPL Gate 2 E-Waste & Litter Sort',
        wardName: 'Ward 84 Whitefield',
        meetingPoint: 'ITPL Main Gate 2 Footpath',
        driveTime: now.add(const Duration(days: 1, hours: 10)),
        rsvpCount: 9,
        isDemo: true,
      ),
      MicroDrive(
        id: 'drive-03',
        title: 'Bellandur Lake Buffer Edge Sweep',
        wardName: 'Ward 150 Bellandur',
        meetingPoint: 'Bellandur Lake Service Rd North',
        driveTime: now.add(const Duration(days: 2, hours: 7)),
        rsvpCount: 22,
        isDemo: true,
      ),
    ];
  }

  static CitizenProfile seedCitizenProfile() {
    return const CitizenProfile(
      id: 'guest-bengaluru-01',
      displayName: 'Guest Citizen (Bengaluru)',
      wardName: 'Ward 151 Koramangala',
      verifiedFixes: 2,
      drivesJoined: 1,
      consensusVotes: 4,
      civicPoints: 145,
    );
  }
}
