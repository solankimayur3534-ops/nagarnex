import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nagarnex/core/city_locator.dart';
import 'package:nagarnex/core/geo_utils.dart';
import 'package:nagarnex/main.dart';
import 'package:nagarnex/models/waste_report.dart';
import 'package:nagarnex/services/app_state.dart';
import 'package:nagarnex/services/supabase_service.dart';
import 'package:nagarnex/widgets/judge_tour.dart';
import 'package:nagarnex/widgets/rank_badge.dart';

void main() {
  test('GeoUtils clusters matching waste type within 150m only', () {
    final seed = SupabaseService.seedWasteReports();

    // Koramangala seed is at (12.9352, 77.6245) with Wet/Food
    final match = GeoUtils.findMatchingCluster(
      reports: seed,
      point: const LatLng(12.9355, 77.6247),
      wasteType: 'Wet/Food',
    );
    expect(match, isNotNull);
    expect(match!.wardName, 'Ward 151 Koramangala');

    // Different waste type at same spot should NOT merge
    final mismatch = GeoUtils.findMatchingCluster(
      reports: seed,
      point: const LatLng(12.9355, 77.6247),
      wasteType: 'E-Waste',
    );
    expect(mismatch, isNull);

    // >150m away should NOT merge
    final far = GeoUtils.findMatchingCluster(
      reports: seed,
      point: const LatLng(12.9500, 77.6245),
      wasteType: 'Wet/Food',
    );
    expect(far, isNull);
  });

  test('GeoUtils enforces 50m verification proximity', () {
    const pin = LatLng(12.9352, 77.6245);
    expect(
      GeoUtils.isWithinVerificationRadius(
        originalPin: pin,
        verifyPin: const LatLng(12.9353, 77.6246),
      ),
      isTrue,
    );
    expect(
      GeoUtils.isWithinVerificationRadius(
        originalPin: pin,
        verifyPin: const LatLng(12.9370, 77.6245),
      ),
      isFalse,
    );
  });

  test('SupabaseService.computeWardStats handles null resolvedAt safely', () {
    final anomaly = WasteReport(
      id: 'anomaly-1',
      wardName: 'Ward 999 Test',
      placeName: 'Test Road',
      lat: 12.97,
      lng: 77.59,
      wasteType: 'Plastic',
      severity: 'Medium',
      aiConfidence: 0.9,
      status: ReportStatus.verifiedCleared,
      reportCount: 2,
      isRecurring: false,
      beforePhotoUrl: 'demo://b',
      verifyVotes: 3,
      slaDeadline: DateTime.now(),
      resolvedAt: null, // Regression check: should not throw!
      isDemo: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    );

    final stats = SupabaseService.computeWardStats([anomaly]);
    expect(stats.length, 1);
    expect(stats.first.clearedSpots, 1);
  });

  test('NagarNexNotifier merges 150m reports, verifies clearance, and RSVPs',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(nagarNexProvider.notifier);
    final initialCount = container
        .read(nagarNexProvider)
        .reports
        .firstWhere((r) => r.id == 'demo-koramangala-03')
        .reportCount;

    // 1. Submit duplicate Wet/Food within 150m of Koramangala
    final res = await notifier.submitWasteReport(
      wardName: 'Ward 151 Koramangala',
      placeName: 'Koramangala 80ft Rd',
      lat: 12.9353,
      lng: 77.6246,
      wasteType: 'Wet/Food',
      severity: 'High',
      aiConfidence: 0.95,
      photoBytes: Uint8List.fromList([1, 2, 3, 4]),
    );
    expect(res.merged, isTrue);
    expect(res.report.reportCount, initialCount + 1);

    // 2. Verify clearance transitions status to verifiedCleared
    final verified = await notifier.submitVerification(
      report: res.report,
      afterPhotoBytes: Uint8List.fromList([5, 6, 7, 8]),
      markClearedNow: true,
    );
    expect(verified.status, ReportStatus.verifiedCleared);
    expect(verified.resolvedAt, isNotNull);

    // 3. Toggle RSVP on first micro-drive
    final drive = container.read(nagarNexProvider).drives.first;
    final beforeRsvp = drive.rsvpCount;
    await notifier.toggleDriveRsvp(drive);
    final updatedDrive = container
        .read(nagarNexProvider)
        .drives
        .firstWhere((d) => d.id == drive.id);
    expect(updatedDrive.rsvpCount, beforeRsvp + 1);
    expect(updatedDrive.hasJoined, isTrue);
  });

  testWidgets('NagarNexApp renders landing page and navigates core views',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: NagarNexApp()));
    await tester.pumpAndSettle();

    expect(find.text('NagarNex'), findsOneWidget);
    expect(find.text('Launch App'), findsOneWidget);

    // Navigate to Roadside Board from Landing Page
    await tester.tap(find.text('Roadside Board').first);
    await tester.pumpAndSettle();
    expect(find.text('Verified Street Solutions (Bangalore)'), findsOneWidget);

    // Navigate to Ward Index
    await tester.tap(find.text('Ward Index'));
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru Ward Waste Index & Clearance Ledger'),
        findsOneWidget);

    // Navigate to Micro-Drives
    await tester.tap(find.text('Micro-Drives'));
    await tester.pumpAndSettle();
    expect(find.text('Community Clean-Up Micro-Drives'), findsOneWidget);
  });

  testWidgets('Mobile 375x812 renders all routes without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: NagarNexApp()));
    await tester.pumpAndSettle();

    // Navigate back to Landing if router retained previous test route
    if (find.text('NagarNex').evaluate().isNotEmpty &&
        find.text('Launch App').evaluate().isEmpty) {
      await tester.tap(find.text('NagarNex').first);
      await tester.pumpAndSettle();
    }
    expect(find.text('Launch App'), findsOneWidget);

    await tester.tap(find.text('Launch App'));
    await tester.pumpAndSettle();

    // Tap bottom nav items on mobile
    await tester.tap(find.text('Ward Index'));
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru Ward Waste Index & Clearance Ledger'),
        findsOneWidget);

    await tester.tap(find.text('Micro-Drives'));
    await tester.pumpAndSettle();
    expect(find.text('Community Clean-Up Micro-Drives'), findsOneWidget);

    await tester.tap(find.text('Rectified Board'));
    await tester.pumpAndSettle();
    expect(find.text('Verified Street Solutions (Bangalore)'), findsOneWidget);

    // Tap Report button to verify Intake on 375px mobile
    await tester.tap(find.byTooltip('Report Waste'));
    await tester.pumpAndSettle();
    expect(find.text('15-Second AI Waste Intake'), findsOneWidget);
  });

  test('CivicRank & 4-step Judge Tour match expected spec', () {
    expect(CivicRank.fromPoints(0).name, 'Sprout');
    expect(CivicRank.fromPoints(145).name, 'Sapling');
    expect(CivicRank.fromPoints(500).name, 'Protector');
    expect(CivicRank.fromPoints(2600).name, 'Legend');
    expect(CivicRank.pointsToNextRank(145), 105);
    expect(kJudgeTourSteps.length, 4);
  });

  test('CityLocator resolves Rajkot and Bengaluru dynamically', () async {
    final blr = await CityLocator.resolveLocationDetails(
        const LatLng(12.9718, 77.6412));
    expect(blr.city, 'Bengaluru');

    final rajkot = await CityLocator.resolveLocationDetails(
        const LatLng(22.3039, 70.8022));
    expect(rajkot.city, 'Rajkot');
  });
}
