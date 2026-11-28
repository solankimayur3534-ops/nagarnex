import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'screens/bi_dashboard_screen.dart';
import 'screens/central_hub_screen.dart';
import 'screens/drives_screen.dart';
import 'screens/intake_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/live_map_screen.dart';
import 'screens/roadside_board_screen.dart';
import 'screens/ward_index_screen.dart';
import 'widgets/nav_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: NagarNexApp()));
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return NavShell(
          currentRoute: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/map',
          builder: (context, state) => const LiveMapScreen(),
        ),
        GoRoute(
          path: '/intake',
          builder: (context, state) => const IntakeScreen(),
        ),
        GoRoute(
          path: '/ward-index',
          builder: (context, state) => const WardIndexScreen(),
        ),
        GoRoute(
          path: '/drives',
          builder: (context, state) => const DrivesScreen(),
        ),
        GoRoute(
          path: '/board',
          builder: (context, state) => const RoadsideBoardScreen(),
        ),
        GoRoute(
          path: '/central',
          builder: (context, state) => const CentralHubScreen(),
        ),
        GoRoute(
          path: '/bi-dashboard',
          builder: (context, state) => const BiDashboardScreen(),
        ),
      ],
    ),
  ],
);

class NagarNexApp extends StatelessWidget {
  const NagarNexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NagarNex — Bengaluru Waste Accountability',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          primary: AppColors.forest,
          secondary: AppColors.emerald,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
          ),
        ),
      ),
    );
  }
}
