import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

/// A single step in the simplified 4-step Judge Demo Tour.
class JudgeTourStep {
  final String emoji;
  final String title;
  final String desc;
  final String? route;

  const JudgeTourStep({
    required this.emoji,
    required this.title,
    required this.desc,
    this.route,
  });
}

const List<JudgeTourStep> kJudgeTourSteps = [
  JudgeTourStep(
    emoji: '👋',
    title: 'Welcome to NagarNex',
    desc: 'Bengaluru\'s citizen-verified waste accountability platform: '
        '15-second AI reporting, 150m blackspot clustering, and GPS-matched '
        'Before/After proof.',
  ),
  JudgeTourStep(
    emoji: '🗺️',
    title: 'Live Map & 150m Clustering',
    desc: 'Explore Bengaluru blackspots across wards. Duplicate reports within '
        '150m auto-merge to prevent ticket spam and escalate recurring alerts.',
    route: '/map',
  ),
  JudgeTourStep(
    emoji: '📸',
    title: '15-Second AI Waste Intake',
    desc: 'Capture or upload a street waste photo — Vision AI tags waste type, '
        'severity, and flags faces/plates while 1-click GPS verifies proximity.',
    route: '/intake',
  ),
  JudgeTourStep(
    emoji: '✅',
    title: 'Ward Index & Verified Proof Board',
    desc: 'Spots only close with GPS-matched After photos + citizen votes. '
        'Rectified streets and Ward Civic Scores are published on the QR Board.',
    route: '/board',
  ),
];

class JudgeTourController {
  static const _key = 'nagarnex_tour_done';

  static Future<bool> hasSeenTour() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markTourDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, true);
    } catch (_) {}
  }
}

/// Simplified 4-step guided tour overlay for hackathon judges.
class JudgeTourOverlay extends StatefulWidget {
  const JudgeTourOverlay({super.key});

  @override
  State<JudgeTourOverlay> createState() => _JudgeTourOverlayState();
}

class _JudgeTourOverlayState extends State<JudgeTourOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late AnimationController _anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int nextStep) async {
    await _anim.reverse();
    if (!mounted) return;
    setState(() => _step = nextStep);
    final route = kJudgeTourSteps[nextStep].route;
    if (route != null && mounted) {
      context.go(route);
    }
    _anim.forward();
  }

  void _next() {
    if (_step < kJudgeTourSteps.length - 1) {
      _goToStep(_step + 1);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_step > 0) {
      _goToStep(_step - 1);
    }
  }

  Future<void> _finish() async {
    await JudgeTourController.markTourDone();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = kJudgeTourSteps[_step];
    final isLast = _step == kJudgeTourSteps.length - 1;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _finish,
            child: Container(
              color: const Color(0xFF041F17).withValues(alpha: 0.78),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: isMobile ? 0 : 24,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 20),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF064E3B), Color(0xFF041F17)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: isMobile
                                ? const BorderRadius.vertical(
                                    top: Radius.circular(22))
                                : BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.emeraldMint.withValues(alpha: 0.35),
                              width: 1.4,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x88000000),
                                blurRadius: 28,
                                offset: Offset(0, -6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.emeraldMint
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.emeraldMint
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      '▶ JUDGE DEMO  ${_step + 1}/${kJudgeTourSteps.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: AppColors.emeraldMint,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _finish,
                                    child: Text(
                                      'Skip',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Colors.white.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children:
                                    List.generate(kJudgeTourSteps.length, (i) {
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    margin: const EdgeInsets.only(right: 6),
                                    width: i == _step ? 22 : 7,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == _step
                                          ? AppColors.emeraldMint
                                          : Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step.emoji,
                                      style: const TextStyle(fontSize: 30)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.title,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          step.desc,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.5,
                                            color: Colors.white
                                                .withValues(alpha: 0.88),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  if (_step > 0) ...[
                                    OutlinedButton(
                                      onPressed: _prev,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.3)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: const Text('← Back'),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _next,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.emeraldMint,
                                        foregroundColor:
                                            const Color(0xFF041F17),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 13),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        isLast ? 'Finish Tour' : 'Next →',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
