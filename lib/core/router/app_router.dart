import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/home_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/state/auth_controller.dart';
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
        path: AppRoute.home.path,
        name: AppRoute.home.name,
        builder: (_, __) => const HomeScreen(),
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
    return location == AppRoute.home.path ? null : AppRoute.home.path;
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
