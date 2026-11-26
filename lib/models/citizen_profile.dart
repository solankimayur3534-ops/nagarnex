class CitizenProfile {
  final String id;
  final String displayName;
  final String wardName;
  final int verifiedFixes;
  final int drivesJoined;
  final int consensusVotes;
  final int civicPoints;

  const CitizenProfile({
    required this.id,
    required this.displayName,
    required this.wardName,
    required this.verifiedFixes,
    required this.drivesJoined,
    required this.consensusVotes,
    required this.civicPoints,
  });

  CitizenProfile copyWith({
    String? id,
    String? displayName,
    String? wardName,
    int? verifiedFixes,
    int? drivesJoined,
    int? consensusVotes,
    int? civicPoints,
  }) {
    return CitizenProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      wardName: wardName ?? this.wardName,
      verifiedFixes: verifiedFixes ?? this.verifiedFixes,
      drivesJoined: drivesJoined ?? this.drivesJoined,
      consensusVotes: consensusVotes ?? this.consensusVotes,
      civicPoints: civicPoints ?? this.civicPoints,
    );
  }

  factory CitizenProfile.fromJson(Map<String, dynamic> json) {
    return CitizenProfile(
      id: json['id']?.toString() ?? 'guest-citizen',
      displayName: json['display_name']?.toString() ?? 'Bengaluru Citizen',
      wardName: json['ward_name']?.toString() ?? 'Ward 151 Koramangala',
      verifiedFixes: (json['verified_fixes'] as num?)?.toInt() ?? 0,
      drivesJoined: (json['drives_joined'] as num?)?.toInt() ?? 0,
      consensusVotes: (json['consensus_votes'] as num?)?.toInt() ?? 0,
      civicPoints: (json['civic_points'] as num?)?.toInt() ?? 0,
    );
  }

  String get civicTier {
    if (civicPoints >= 300) return 'Ward Champion';
    if (civicPoints >= 150) return 'Street Steward';
    if (civicPoints >= 50) return 'Active Verifier';
    return 'Citizen Starter';
  }
}
