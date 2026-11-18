import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/auth/auth_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/audit/audit_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/cash/cash_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/entry/entry_screen.dart';
import 'features/exit/exit_screen.dart';
import 'features/monthly/monthly_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/tenant/tenant_picker_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authProvider);
  const publicRoutes = {'/login', '/registro'};
  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (!auth.ready) return path == '/cargando' ? null : '/cargando';
      if (!auth.loggedIn) return publicRoutes.contains(path) ? null : '/login';
      if (auth.tenantUuid == null) return path == '/parqueaderos' ? null : '/parqueaderos';
      if (publicRoutes.contains(path) || path == '/cargando') return '/inicio';
      return null;
    },
    routes: [
      GoRoute(path: '/cargando', builder: (context, state) => const _Splash()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/registro', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/parqueaderos', builder: (context, state) => const TenantPickerScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/inicio', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/entrada', builder: (context, state) => const EntryScreen()),
          GoRoute(path: '/salidas', builder: (context, state) => ExitScreen(initialPlate: state.uri.queryParameters['placa'])),
          GoRoute(path: '/mensual', builder: (context, state) => const MonthlyScreen()),
          GoRoute(path: '/caja', builder: (context, state) => const CashScreen()),
          GoRoute(path: '/configuracion', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/auditoria', builder: (context, state) => const AuditScreen()),
        ],
      ),
    ],
  );
});

class SpParqueaderosApp extends ConsumerStatefulWidget {
  const SpParqueaderosApp({super.key});

  @override
  ConsumerState<SpParqueaderosApp> createState() => _SpParqueaderosAppState();
}

class _SpParqueaderosAppState extends ConsumerState<SpParqueaderosApp> {
  @override
  void initState() {
    super.initState();
    ref.read(authProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SP Parqueaderos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      // Textos de Material (calendarios, botones de dialogos) en espanol.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(data: media.copyWith(textScaler: AppText.scaler(media.textScaler)), child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
