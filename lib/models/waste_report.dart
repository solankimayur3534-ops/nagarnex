enum ReportStatus {
  open,
  pendingVerification,
  verifiedCleared;

  String get dbValue {
    switch (this) {
      case ReportStatus.open:
        return 'open';
      case ReportStatus.pendingVerification:
        return 'pending_verification';
      case ReportStatus.verifiedCleared:
        return 'verified_cleared';
    }
  }

  String get label {
    switch (this) {
      case ReportStatus.open:
        return 'Open Blackspot';
      case ReportStatus.pendingVerification:
        return 'Pending Citizen Proof';
      case ReportStatus.verifiedCleared:
        return 'Verified Cleared';
    }
  }

  static ReportStatus fromDb(String? value) {
    switch (value) {
      case 'pending_verification':
        return ReportStatus.pendingVerification;
      case 'verified_cleared':
        return ReportStatus.verifiedCleared;
      default:
        return ReportStatus.open;
    }
  }
}

class WasteReport {
  final String id;
  final String wardName;
  final String placeName;
  final double lat;
  final double lng;
  final String wasteType;
  final String severity;
  final double aiConfidence;
  final ReportStatus status;
  final int reportCount;
  final bool isRecurring;
  final String beforePhotoUrl;
  final String? afterPhotoUrl;
  final int verifyVotes;
  final DateTime slaDeadline;
  final DateTime? resolvedAt;
  final bool isDemo;
  final DateTime createdAt;

  const WasteReport({
    required this.id,
    required this.wardName,
    required this.placeName,
    required this.lat,
    required this.lng,
    required this.wasteType,
    required this.severity,
    required this.aiConfidence,
    required this.status,
    required this.reportCount,
    required this.isRecurring,
    required this.beforePhotoUrl,
    this.afterPhotoUrl,
    required this.verifyVotes,
    required this.slaDeadline,
    this.resolvedAt,
    required this.isDemo,
    required this.createdAt,
  });

  WasteReport copyWith({
    String? id,
    String? wardName,
    String? placeName,
    double? lat,
    double? lng,
    String? wasteType,
    String? severity,
    double? aiConfidence,
    ReportStatus? status,
    int? reportCount,
    bool? isRecurring,
    String? beforePhotoUrl,
    String? afterPhotoUrl,
    int? verifyVotes,
    DateTime? slaDeadline,
    DateTime? resolvedAt,
    bool? isDemo,
    DateTime? createdAt,
  }) {
    return WasteReport(
      id: id ?? this.id,
      wardName: wardName ?? this.wardName,
      placeName: placeName ?? this.placeName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      wasteType: wasteType ?? this.wasteType,
      severity: severity ?? this.severity,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      status: status ?? this.status,
      reportCount: reportCount ?? this.reportCount,
      isRecurring: isRecurring ?? this.isRecurring,
      beforePhotoUrl: beforePhotoUrl ?? this.beforePhotoUrl,
      afterPhotoUrl: afterPhotoUrl ?? this.afterPhotoUrl,
      verifyVotes: verifyVotes ?? this.verifyVotes,
      slaDeadline: slaDeadline ?? this.slaDeadline,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isDemo: isDemo ?? this.isDemo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory WasteReport.fromJson(Map<String, dynamic> json) {
    return WasteReport(
      id: json['id']?.toString() ?? '',
      wardName: json['ward_name']?.toString() ?? 'Ward 150 Bellandur',
      placeName: json['place_name']?.toString() ?? 'Bengaluru Street',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      wasteType: json['waste_type']?.toString() ?? 'Mixed/Debris',
      severity: json['severity']?.toString() ?? 'Medium',
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble() ?? 0.90,
      status: ReportStatus.fromDb(json['status']?.toString()),
      reportCount: (json['report_count'] as num?)?.toInt() ?? 1,
      isRecurring: json['is_recurring'] as bool? ?? false,
      beforePhotoUrl: json['before_photo_url']?.toString() ?? '',
      afterPhotoUrl: json['after_photo_url']?.toString(),
      verifyVotes: (json['verify_votes'] as num?)?.toInt() ?? 0,
      slaDeadline: DateTime.tryParse(json['sla_deadline']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      isDemo: json['is_demo'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'ward_name': wardName,
      'place_name': placeName,
      'lat': lat,
      'lng': lng,
      'waste_type': wasteType,
      'severity': severity,
      'ai_confidence': aiConfidence,
      'status': status.dbValue,
      'report_count': reportCount,
      'is_recurring': isRecurring,
      'before_photo_url': beforePhotoUrl,
      if (afterPhotoUrl != null) 'after_photo_url': afterPhotoUrl,
      'verify_votes': verifyVotes,
      'sla_deadline': slaDeadline.toUtc().toIso8601String(),
      if (resolvedAt != null)
        'resolved_at': resolvedAt!.toUtc().toIso8601String(),
      'is_demo': isDemo,
    };
  }

  String get clearanceDurationLabel {
    if (resolvedAt == null) return 'In progress';
    final diff = resolvedAt!.difference(createdAt).abs();
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours >= 24) {
      return '${(hours / 24).floor()}d ${hours % 24}h';
    }
    if (hours >= 1) return '${hours}h ${mins}m';
    return '${mins}m';
  }
}
