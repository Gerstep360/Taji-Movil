import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/router/app_routes.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/auth/state/auth_controller.dart';
import 'package:taji/shared/widgets/taji_drawer.dart';

class _FakeAuth extends ChangeNotifier implements AuthController {
  _FakeAuth(this.user);

  @override
  AuthStatus status = AuthStatus.authenticated;

  @override
  TajiUser? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TajiUser _user(String slug, List<String> permissions) => TajiUser(
  id: 1,
  email: '$slug@taji.test',
  firstName: 'Ana',
  lastName: 'Rojas',
  fullName: 'Ana Rojas',
  phone: '',
  role: TajiRole(
    slug: slug,
    name: slug,
    description: '',
    permissions: permissions,
  ),
);

Future<void> _openDrawer(WidgetTester tester, TajiUser user) async {
  tester.view.physicalSize = const Size(1080, 4500);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoute.home.path,
    routes: [
      GoRoute(
        path: AppRoute.home.path,
        builder: (_, _) => const Scaffold(drawer: TajiDrawer(), body: Text('Inicio')),
      ),
      GoRoute(
        path: AppRoute.reportIncident.path,
        builder: (_, _) => const Scaffold(body: Text('Formulario CU18')),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>(
      create: (_) => _FakeAuth(user),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  await tester.pumpAndSettle();
  // El paquete 3 está plegado por defecto.
  await tester.tap(find.text('Incidencias e IA'));
  await tester.pumpAndSettle();
}

void main() {
  test('la ruta de CU18 es estable', () {
    expect(AppRoute.reportIncident.path, '/incidencias/nueva');
  });

  testWidgets('el menú abre "Reportar Incidencia" a quien tiene permiso', (
    tester,
  ) async {
    await _openDrawer(tester, _user('residente', ['report_incidents']));

    await tester.tap(find.text('Reportar Incidencia'));
    await tester.pumpAndSettle();
    expect(find.text('Formulario CU18'), findsOneWidget);
  });

  testWidgets('sin permiso la opción sigue como "Pronto"', (tester) async {
    await _openDrawer(tester, _user('seguridad', ['validate_visits']));

    await tester.tap(find.text('Reportar Incidencia'));
    await tester.pumpAndSettle();
    expect(find.text('Formulario CU18'), findsNothing);
  });
}
