import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AppColors {
  static const Color background = Color(0xFFF4F7F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF2EF);
  static const Color ink = Color(0xFF0B1F17);
  static const Color inkSecondary = Color(0xFF374151);
  static const Color inkMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFDCE5DF);

  static const Color forest = Color(0xFF064E3B);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF047857);
  static const Color emeraldMint = Color(0xFFA7F3D0);
  static const Color emeraldSoft = Color(0xFFECFDF5);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBright = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0xFFE0F2FE);
}

class AppConstants {
  static const String appName = 'NagarNex';
  static const String city = 'Bengaluru';
  static const String disclaimerText =
      'NagarNex is an independent citizen-led initiative for Bengaluru public waste accountability. Not affiliated with any government or municipal body.';

  /// Default map center (Bengaluru MG Road / City Center)
  static const LatLng bengaluruCenter = LatLng(12.9716, 77.5946);

  /// Strict Greater Bengaluru bounding box
  static final LatLngBounds bengaluruBounds = LatLngBounds(
    const LatLng(12.78, 77.38),
    const LatLng(13.18, 77.82),
  );

  static bool isInsideBengaluru(LatLng point) =>
      point.latitude >= 12.78 &&
      point.latitude <= 13.18 &&
      point.longitude >= 77.38 &&
      point.longitude <= 77.82;

  static LatLng clampToBengaluru(LatLng point) => LatLng(
        point.latitude.clamp(12.78, 13.18).toDouble(),
        point.longitude.clamp(77.38, 77.82).toDouble(),
      );

  /// Clustering & verification thresholds
  static const double clusterRadiusMeters = 150.0;
  static const int recurringThresholdCount = 5;
  static const double verifyProximityMeters = 50.0;
  static const int requiredVerifyVotes = 3;

  /// Optional runtime config via `--dart-define`
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String liveBoardUrl = String.fromEnvironment(
    'NAGARNEX_PUBLIC_URL',
    defaultValue: 'https://nagarnex.vercel.app/board',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasGeminiConfig => geminiApiKey.isNotEmpty;

  static const List<String> wasteTypes = [
    'Plastic',
    'Wet/Food',
    'Glass',
    'E-Waste',
    'Mixed/Debris',
  ];

  static const List<String> severities = ['High', 'Medium', 'Low'];

  static const List<Map<String, dynamic>> bengaluruPresets = [
    {
      'ward': 'Ward 151 Koramangala',
      'place': 'Koramangala 80ft Road Bus Stop',
      'lat': 12.9352,
      'lng': 77.6245,
    },
    {
      'ward': 'Ward 150 Bellandur',
      'place': 'Bellandur Lake Service Road',
      'lat': 12.9304,
      'lng': 77.6784,
    },
    {
      'ward': 'Ward 80 Indiranagar',
      'place': 'Indiranagar 12th Main Corner',
      'lat': 12.9718,
      'lng': 77.6412,
    },
    {
      'ward': 'Ward 84 Whitefield',
      'place': 'ITPL Main Road Gate 2',
      'lat': 12.9850,
      'lng': 77.7366,
    },
    {
      'ward': 'Ward 174 HSR Layout',
      'place': 'HSR Sector 2 27th Main',
      'lat': 12.9121,
      'lng': 77.6446,
    },
    {
      'ward': 'Ward 169 Jayanagar',
      'place': 'Jayanagar 4th Block Market Edge',
      'lat': 12.9299,
      'lng': 77.5838,
    },
  ];
}
