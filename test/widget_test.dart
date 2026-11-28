import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nagarnex/core/city_locator.dart';
import 'package:nagarnex/core/constants.dart';
import 'package:nagarnex/core/geo_utils.dart';
import 'package:nagarnex/main.dart';
import 'package:nagarnex/models/waste_report.dart';
import 'package:nagarnex/services/ai_vision_service.dart';
import 'package:nagarnex/services/app_state.dart';
import 'package:nagarnex/services/supabase_service.dart';
import 'package:nagarnex/widgets/judge_tour.dart';
import 'package:nagarnex/widgets/passport_drawer.dart';
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

    // Open Passport Drawer -> Central Command Hub on 375px mobile
    await tester.tap(find.byTooltip('Citizen Impact Passport'));
    await tester.pumpAndSettle();
    final hubBtn = find.text('Open Central Command Hub →');
    await tester.ensureVisible(hubBtn);
    await tester.pumpAndSettle();
    await tester.tap(hubBtn);
    await tester.pumpAndSettle();
    expect(find.text('Centralized Responsibility & Escalation Hub'),
        findsOneWidget);
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

  test('AiVisionService sanitizes internal provider names and detects MIME types', () {
    expect(
      AiVisionService.sanitizeUserMessage('Gemini AI Studio API key invalid'),
      'Could not analyze image right now.',
    );
    expect(
      AiVisionService.sanitizeUserMessage('NVIDIA NIM error (429)'),
      'Could not analyze image right now.',
    );
    expect(
      AiVisionService.sanitizeUserMessage('Clean street road with no garbage.'),
      'Clean street road with no garbage.',
    );

    expect(
      AiVisionService.detectMimeType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
      'image/jpeg',
    );
    expect(
      AiVisionService.detectMimeType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])),
      'image/png',
    );
    expect(
      AiVisionService.detectMimeType(Uint8List.fromList(
        [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
      )),
      'image/webp',
    );
  });

  testWidgets('Module 01 LiveMap and all connected modules work on 375x812 mobile',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: NagarNexApp()));
    await tester.pumpAndSettle();

    // Go to Module 01 (Live Map)
    if (find.text('Launch App').evaluate().isNotEmpty) {
      await tester.tap(find.text('Launch App'));
      await tester.pumpAndSettle();
    } else {
      await tester.tap(find.text('Live Map'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Snap & Classify Waste'), findsOneWidget);

    // 1. Test waste category filter pill inside Module 01
    final plasticPill = find.text('Plastic & Mixed');
    await tester.ensureVisible(plasticPill);
    await tester.tap(plasticPill);
    await tester.pumpAndSettle();

    final allPill = find.textContaining('All Spots');
    await tester.ensureVisible(allPill);
    await tester.tap(allPill);
    await tester.pumpAndSettle();

    // 2. Test Ward Health card connection -> Module 02 (Ward Index)
    final wardLedgerBtn = find.textContaining('Open Ward Ledger').first;
    await tester.ensureVisible(wardLedgerBtn);
    await tester.pumpAndSettle();
    await tester.tap(wardLedgerBtn);
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru Ward Waste Index & Clearance Ledger'),
        findsOneWidget);

    // Return to Module 01 (Live Map)
    await tester.tap(find.text('Live Map'));
    await tester.pumpAndSettle();

    // 3. Test 15s Citizen Intake connection -> /intake
    final snapBtn = find.text('Snap & Classify Waste');
    await tester.ensureVisible(snapBtn);
    await tester.pumpAndSettle();
    await tester.tap(snapBtn);
    await tester.pumpAndSettle();
    expect(find.text('15-Second AI Waste Intake'), findsOneWidget);

    // Return to Module 01 (Live Map)
    await tester.tap(find.text('Live Map'));
    await tester.pumpAndSettle();

    // 4. Select an active blackspot in Module 01, then open VerifyProofModal
    final activeSpotCard = find.text('Koramangala 80ft Road Bus Stop').last;
    await tester.ensureVisible(activeSpotCard);
    await tester.pumpAndSettle();
    await tester.tap(activeSpotCard);
    await tester.pumpAndSettle();

    final verifyBtn = find.text('Verify Fix →').first;
    await tester.ensureVisible(verifyBtn);
    await tester.pumpAndSettle();
    await tester.tap(verifyBtn);
    await tester.pumpAndSettle();
    expect(find.text('Verify Street Waste Clearance'), findsOneWidget);

    // Close modal cleanly
    final closeVerifyBtn = find.text('Still Uncleared ×');
    await tester.ensureVisible(closeVerifyBtn);
    await tester.pumpAndSettle();
    await tester.tap(closeVerifyBtn);
    await tester.pumpAndSettle();
    expect(find.text('Verify Street Waste Clearance'), findsNothing);

    // 5. Test Micro-Drives connection from Module 01 -> Module 03 (/drives)
    final startDriveBtn = find.byTooltip('Start Clean-Up Drive').first;
    await tester.ensureVisible(startDriveBtn);
    await tester.pumpAndSettle();
    await tester.tap(startDriveBtn);
    await tester.pumpAndSettle();
    expect(find.text('Community Clean-Up Micro-Drives'), findsOneWidget);

    // Verify interactive Completed filter tab on Micro-Drives
    await tester.tap(find.textContaining('Completed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Indiranagar 12th Main Completed Clean-Up'),
        findsOneWidget);

    // Return to Module 01 (Live Map) and test Rectified Board connection -> Module 04 (/board)
    await tester.tap(find.text('Live Map'));
    await tester.pumpAndSettle();
    final boardLink = find.text('View Board →');
    await tester.ensureVisible(boardLink);
    await tester.pumpAndSettle();
    await tester.tap(boardLink);
    await tester.pumpAndSettle();
    expect(find.text('Verified Street Solutions (Bangalore)'), findsOneWidget);
  });

  test('Admin Policy Controls require password in NagarNexNotifier', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(nagarNexProvider.notifier);
    expect(container.read(nagarNexProvider).isAdminUnlocked, false);

    // Mutations must be ignored while locked
    notifier.setAdminRole('National Civic Admin');
    await notifier.setAdminEnforcement(
      enforceCameraOnly: true,
      enforceGpsOnly: true,
    );
    expect(container.read(nagarNexProvider).adminRole, 'Citizen');
    expect(container.read(nagarNexProvider).enforceCameraOnly, false);
    expect(container.read(nagarNexProvider).enforceGpsOnly, false);

    // Wrong password rejected
    expect(notifier.verifyAndUnlockAdmin('wrong-password'), false);
    expect(container.read(nagarNexProvider).isAdminUnlocked, false);

    // Valid password unlocks admin role + policy controls
    expect(notifier.verifyAndUnlockAdmin(AppConstants.adminPasscode), true);
    expect(container.read(nagarNexProvider).isAdminUnlocked, true);

    notifier.setAdminRole('National Civic Admin');
    await notifier.setAdminEnforcement(enforceCameraOnly: true);
    expect(container.read(nagarNexProvider).adminRole, 'National Civic Admin');
    expect(container.read(nagarNexProvider).enforceCameraOnly, true);

    // Re-locking resets role safely to Citizen
    notifier.lockAdmin();
    expect(container.read(nagarNexProvider).isAdminUnlocked, false);
    expect(container.read(nagarNexProvider).adminRole, 'Citizen');
  });

  testWidgets('PassportDrawer prompts for admin password before policy toggle',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PassportDrawer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Password required to modify'), findsNWidgets(2));

    // Tapping Enforce Camera Only while locked opens password dialog
    final camToggle = find.text('Enforce Camera Only');
    await tester.ensureVisible(camToggle);
    await tester.tap(camToggle);
    await tester.pumpAndSettle();

    expect(find.text('Admin Authentication Required'), findsOneWidget);

    // Wrong password displays error and keeps controls locked
    await tester.enterText(find.byType(TextField), 'bad-pass');
    await tester.tap(find.text('Unlock Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect admin password. Please try again.'),
        findsOneWidget);

    // Correct password unlocks and applies Enforce Camera Only
    await tester.enterText(find.byType(TextField), AppConstants.adminPasscode);
    await tester.tap(find.text('Unlock Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Authentication Required'), findsNothing);
    expect(find.text('Lock'), findsOneWidget);
    expect(find.text('Unlocked · Synced via Supabase'), findsNWidgets(2));
  });

  testWidgets('BI Dashboard renders on 375x812 mobile with slicers and demo notice',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: NagarNexApp()));
    await tester.pumpAndSettle();

    // Navigate into app, then open Power BI Dashboard via AppBar action
    if (find.text('Launch App').evaluate().isNotEmpty) {
      await tester.tap(find.text('Launch App'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Power BI Analytics Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Bengaluru Waste Accountability BI Dashboard'),
        findsOneWidget);
    expect(find.textContaining('Demo / Dummy Dataset Notice'), findsOneWidget);

    // Interactive category slicer
    final plasticChip = find.widgetWithText(ChoiceChip, 'Plastic');
    await tester.ensureVisible(plasticChip);
    await tester.tap(plasticChip);
    await tester.pumpAndSettle();

    final resetBtn = find.text('Reset Slicers');
    await tester.ensureVisible(resetBtn);
    await tester.pumpAndSettle();
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();
  });
}
