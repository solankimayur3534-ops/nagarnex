class MicroDrive {
  final String id;
  final String? reportId;
  final String title;
  final String wardName;
  final String meetingPoint;
  final DateTime driveTime;
  final int rsvpCount;
  final bool isDemo;
  final bool hasJoined;

  const MicroDrive({
    required this.id,
    this.reportId,
    required this.title,
    required this.wardName,
    required this.meetingPoint,
    required this.driveTime,
    required this.rsvpCount,
    this.isDemo = false,
    this.hasJoined = false,
  });

  MicroDrive copyWith({
    String? id,
    String? reportId,
    String? title,
    String? wardName,
    String? meetingPoint,
    DateTime? driveTime,
    int? rsvpCount,
    bool? isDemo,
    bool? hasJoined,
  }) {
    return MicroDrive(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      title: title ?? this.title,
      wardName: wardName ?? this.wardName,
      meetingPoint: meetingPoint ?? this.meetingPoint,
      driveTime: driveTime ?? this.driveTime,
      rsvpCount: rsvpCount ?? this.rsvpCount,
      isDemo: isDemo ?? this.isDemo,
      hasJoined: hasJoined ?? this.hasJoined,
    );
  }

  factory MicroDrive.fromJson(Map<String, dynamic> json) {
    return MicroDrive(
      id: json['id']?.toString() ?? '',
      reportId: json['report_id']?.toString(),
      title: json['title']?.toString() ?? 'Community Clean-Up Drive',
      wardName: json['ward_name']?.toString() ?? 'Bengaluru',
      meetingPoint: json['meeting_point']?.toString() ?? 'Main Junction',
      driveTime: DateTime.tryParse(json['drive_time']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 1)),
      rsvpCount: (json['rsvp_count'] as num?)?.toInt() ?? 1,
      isDemo: json['is_demo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      if (reportId != null) 'report_id': reportId,
      'title': title,
      'ward_name': wardName,
      'meeting_point': meetingPoint,
      'drive_time': driveTime.toUtc().toIso8601String(),
      'rsvp_count': rsvpCount,
      'is_demo': isDemo,
    };
  }
}
