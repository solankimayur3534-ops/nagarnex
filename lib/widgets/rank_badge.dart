import 'package:flutter/material.dart';

/// Civic rank tiers based on civicPoints.
class CivicRank {
  final String emoji;
  final String name;
  final int minPoints;
  final int maxPoints; // -1 = no cap
  final Color color;
  final Color bg;

  const CivicRank({
    required this.emoji,
    required this.name,
    required this.minPoints,
    required this.maxPoints,
    required this.color,
    required this.bg,
  });

  static const List<CivicRank> all = [
    CivicRank(emoji: '🌱', name: 'Sprout', minPoints: 0, maxPoints: 99, color: Color(0xFF16A34A), bg: Color(0xFFDCFCE7)),
    CivicRank(emoji: '🌿', name: 'Sapling', minPoints: 100, maxPoints: 249, color: Color(0xFF059669), bg: Color(0xFFD1FAE5)),
    CivicRank(emoji: '🌳', name: 'Guardian', minPoints: 250, maxPoints: 499, color: Color(0xFF064E3B), bg: Color(0xFFA7F3D0)),
    CivicRank(emoji: '🏅', name: 'Protector', minPoints: 500, maxPoints: 999, color: Color(0xFFD97706), bg: Color(0xFFFEF3C7)),
    CivicRank(emoji: '⭐', name: 'Champion', minPoints: 1000, maxPoints: 2499, color: Color(0xFFB45309), bg: Color(0xFFFDE68A)),
    CivicRank(emoji: '🏆', name: 'Legend', minPoints: 2500, maxPoints: -1, color: Color(0xFF7C3AED), bg: Color(0xFFEDE9FE)),
  ];

  static CivicRank fromPoints(int points) {
    for (int i = all.length - 1; i >= 0; i--) {
      if (points >= all[i].minPoints) return all[i];
    }
    return all[0];
  }

  /// Returns 0.0–1.0 progress within this rank's range.
  static double progressInRank(int points) {
    final rank = fromPoints(points);
    if (rank.maxPoints == -1) return 1.0;
    final range = rank.maxPoints - rank.minPoints + 1;
    final earned = points - rank.minPoints;
    return (earned / range).clamp(0.0, 1.0);
  }

  /// Points needed to reach next rank.
  static int pointsToNextRank(int points) {
    final rank = fromPoints(points);
    if (rank.maxPoints == -1) return 0;
    return rank.maxPoints + 1 - points;
  }

  static CivicRank? nextRank(int points) {
    final rank = fromPoints(points);
    final idx = all.indexOf(rank);
    if (idx < all.length - 1) return all[idx + 1];
    return null;
  }
}

/// Compact badge chip — shows emoji + rank name. Use in AppBar or cards.
class RankBadgeChip extends StatelessWidget {
  final int civicPoints;
  const RankBadgeChip({super.key, required this.civicPoints});

  @override
  Widget build(BuildContext context) {
    final rank = CivicRank.fromPoints(civicPoints);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: rank.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rank.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rank.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            rank.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: rank.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full rank card for Passport Drawer — shows rank, progress bar, and next milestone.
class RankPassportCard extends StatelessWidget {
  final int civicPoints;
  const RankPassportCard({super.key, required this.civicPoints});

  @override
  Widget build(BuildContext context) {
    final rank = CivicRank.fromPoints(civicPoints);
    final next = CivicRank.nextRank(civicPoints);
    final progress = CivicRank.progressInRank(civicPoints);
    final toNext = CivicRank.pointsToNextRank(civicPoints);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [rank.bg, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rank.color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: rank.color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(rank.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: rank.color,
                      ),
                    ),
                    Text(
                      'CIVIC RANK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: rank.color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: rank.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$civicPoints pts',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (next != null) ...[ 
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress to ${next.emoji} ${next.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: rank.color.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '$toNext pts to go',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: rank.color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(rank.color),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: rank.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🏆 Maximum rank achieved! Bengaluru thanks you.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: rank.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
