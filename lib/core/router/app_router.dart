import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/home_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/auth/models/taji_user.dart';
import '../../features/security/screens/security_shifts_screen.dart';
import '../../features/security/screens/access_events_screen.dart';
import '../../features/security/data/access_event_repository.dart';
import '../../features/security/screens/shift_logs_screen.dart';
import '../../features/security/screens/handovers_screen.dart';
import '../../features/security/screens/face_verification_screen.dart';
import '../../features/visitors/models/visitor_authorization.dart';
import '../../features/visitors/screens/qr_scan_history_screen.dart';
import '../../features/visitors/screens/visit_consultation_screen.dart';
import '../../features/visitors/screens/visit_qr_scanner_screen.dart';
import '../../features/visitors/screens/visit_qr_screen.dart';
import '../../features/visitors/screens/visitor_authorizations_screen.dart';
import '../../shared/widgets/taji_logo.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static GoRouter create(AuthController auth) => GoRouter(
    initialLocation: AppRoute.splash.path,
    refreshListenable: auth,
    redirect: (_, state) => _redirect(auth, state),
    errorBuilder: (_, __) => const _RouteNotFoundScreen(),
    routes: [
      GoRoute(
        path: AppRoute.visitConsultation.path,
        name: AppRoute.visitConsultation.name,
        builder: (_, __) => const VisitConsultationScreen(),
      ),
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (_, __) => const TajiSplashScreen(),
      ),
      GoRoute(
        path: AppRoute.login.path,
        name: AppRoute.login.name,
        builder: (_, state) => LoginScreen(
          registered: state.uri.queryParameters['registered'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoute.register.path,
        name: AppRoute.register.name,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoute.forgotPassword.path,
        name: AppRoute.forgotPassword.name,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoute.visitorAuthorizations.path,
        name: AppRoute.visitorAuthorizations.name,
        builder: (_, __) => const VisitorAuthorizationsScreen(),
      ),
      // T105 / CU09: QR temporal y vigencia de una autorización concreta.
      GoRoute(
        path: AppRoute.visitQr.path,
        name: AppRoute.visitQr.name,
        builder: (_, state) {
          final id = int.tryParse(
            state.pathParameters['authorizationId'] ?? '',
          );
          if (id == null || id <= 0) return const _RouteNotFoundScreen();
          final seed = state.extra;
          return VisitQrScreen(
            authorizationId: id,
            initialVisitorName: seed is VisitorAuthorization
                ? seed.visitorName
                : '',
            initialUnit: seed is VisitorAuthorization ? seed.unit : '',
          );
        },
      ),
      // T106 / CU10: lector de QR del personal de seguridad.
      GoRoute(
        path: AppRoute.visitQrScanner.path,
        name: AppRoute.visitQrScanner.name,
        builder: (_, __) => const VisitQrScannerScreen(),
      ),
      // CU10: bitácora de escaneos. El registro vive en el servidor, así que
      // a diferencia del historial del lector sobrevive a cerrar la app.
      GoRoute(
        path: AppRoute.qrScanHistory.path,
        name: AppRoute.qrScanHistory.name,
        builder: (_, __) => const QrScanHistoryScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        name: AppRoute.home.name,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoute.accessEvents.path,
        name: AppRoute.accessEvents.name,
        builder: (_, __) => const AccessEventsScreen(),
      ),
      GoRoute(
        path: AppRoute.newAccessEvent.path,
        name: AppRoute.newAccessEvent.name,
        builder: (context, __) => AccessEventFormScreen(
          source: context.read<AccessEventDataSource>(),
        ),
      ),
      GoRoute(
        path: AppRoute.securityShifts.path,
        name: AppRoute.securityShifts.name,
        builder: (_, __) => const SecurityShiftsScreen(),
      ),
      GoRoute(
        path: AppRoute.shiftLogs.path,
        name: AppRoute.shiftLogs.name,
        builder: (_, __) => const ShiftLogsScreen(),
      ),
      GoRoute(
        path: AppRoute.handovers.path,
        name: AppRoute.handovers.name,
        builder: (_, __) => const HandoversScreen(),
      ),
      GoRoute(
        path: AppRoute.faceVerification.path,
        name: AppRoute.faceVerification.name,
        builder: (_, __) => const FaceVerificationScreen(),
      ),
    ],
  );

  static String? _redirect(AuthController auth, GoRouterState state) {
    final location = state.matchedLocation;
    if (auth.status == AuthStatus.initializing) {
      return location == AppRoute.splash.path ? null : AppRoute.splash.path;
    }

    final isGuestRoute = {
      AppRoute.login.path,
      AppRoute.register.path,
      AppRoute.forgotPassword.path,
    }.contains(location);

    if (auth.status == AuthStatus.unauthenticated) {
      return location == AppRoute.splash.path || !isGuestRoute
          ? AppRoute.login.path
          : null;
    }
    if ([
          AppRoute.securityShifts.path,
          AppRoute.shiftLogs.path,
          AppRoute.handovers.path,
        ].contains(location) &&
        auth.user?.canUseSecurityShifts != true) {
      return AppRoute.home.path;
    }
    // La bitácora de escaneos la lee el mismo permiso que valida los QR.
    if (location == AppRoute.qrScanHistory.path &&
        auth.user?.canValidateVisits != true) {
      return AppRoute.home.path;
    }
    if ([AppRoute.accessEvents.path, AppRoute.newAccessEvent.path].contains(location) &&
        auth.user?.canRegisterAccessEvents != true) {
      return AppRoute.home.path;
    }
    return _isAuthenticatedRoute(location) ? null : AppRoute.home.path;
  }

  /// Rutas accesibles con sesión iniciada.
  static const _authenticatedRoutes = [
    AppRoute.home,
    AppRoute.accessEvents,
    AppRoute.newAccessEvent,
    AppRoute.securityShifts,
    AppRoute.shiftLogs,
    AppRoute.handovers,
    AppRoute.faceVerification,
    AppRoute.visitorAuthorizations,
    AppRoute.visitQrScanner,
    AppRoute.qrScanHistory,
    AppRoute.visitQr,
    AppRoute.visitConsultation,
  ];

  static bool _isAuthenticatedRoute(String location) =>
      _authenticatedRoutes.any((route) => _matchesRoute(route.path, location));

  /// Compara una ruta con parámetros contra la ruta realmente visitada,
  /// exigiendo igualdad en los segmentos literales.
  static bool _matchesRoute(String pattern, String location) {
    if (!pattern.contains(':')) return pattern == location;
    final patternParts = pattern.split('/');
    final locationParts = location.split('/');
    if (patternParts.length != locationParts.length) return false;
    for (var index = 0; index < patternParts.length; index++) {
      final expected = patternParts[index];
      if (expected.startsWith(':')) {
        if (locationParts[index].isEmpty) return false;
        continue;
      }
      if (expected != locationParts[index]) return false;
    }
    return true;
  }
}

class TajiSplashScreen extends StatelessWidget {
  const TajiSplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TajiLogo(),
            SizedBox(height: 22),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TajiLogo(),
              const SizedBox(height: 24),
              Text(
                'Esta pantalla no existe',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Vuelve al inicio para continuar.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(AppRoute.home.path),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
