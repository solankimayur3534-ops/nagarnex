import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/waste_report.dart';
import 'constants.dart';

class GeoUtils {
  static const Distance _distance = Distance();

  /// Returns Haversine distance in meters between two LatLng coordinates.
  static double distanceMeters(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Meter, a, b);
  }

  /// Finds an existing active blackspot within [radiusMeters] (default 150m)
  /// matching the same [wasteType] so duplicate reports merge into one cluster.
  static WasteReport? findMatchingCluster({
    required List<WasteReport> reports,
    required LatLng point,
    required String wasteType,
    double radiusMeters = AppConstants.clusterRadiusMeters,
  }) {
    WasteReport? closest;
    double minDistance = double.infinity;

    for (final report in reports) {
      if (report.status == ReportStatus.verifiedCleared) continue;
      if (report.wasteType != wasteType) continue;

      final dist = distanceMeters(point, LatLng(report.lat, report.lng));
      if (dist <= radiusMeters && dist < minDistance) {
        minDistance = dist;
        closest = report;
      }
    }
    return closest;
  }

  /// Checks whether a verification photo's GPS is within [maxMeters] (default 50m)
  /// of the original blackspot pin.
  static bool isWithinVerificationRadius({
    required LatLng originalPin,
    required LatLng verifyPin,
    double maxMeters = AppConstants.verifyProximityMeters,
  }) {
    return distanceMeters(originalPin, verifyPin) <= maxMeters;
  }

  /// Formats remaining SLA duration cleanly (e.g. "4h 12m left" or "Overdue 2h").
  static String formatSlaRemaining(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) {
      final overdue = diff.abs();
      if (overdue.inHours >= 1) {
        return 'Overdue ${overdue.inHours}h ${overdue.inMinutes % 60}m';
      }
      return 'Overdue ${overdue.inMinutes}m';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m SLA left';
    }
    return '${diff.inMinutes}m SLA left';
  }

  /// Formats a report timestamp as relative + IST date/time
  /// e.g. "Just now • 27 Nov, 02:00 AM IST" or "4h ago • 26 Nov, 10:00 PM IST".
  static String formatReportedTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    final String ago;
    if (diff.inMinutes < 1) {
      ago = 'Just now';
    } else if (diff.inMinutes < 60) {
      ago = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      ago = '${diff.inHours}h ago';
    } else {
      ago = '${diff.inDays}d ago';
    }
    final formatted = DateFormat('d MMM, hh:mm a').format(local);
    return '$ago • $formatted IST';
  }
}
