import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/auth/state/auth_controller.dart';
import 'package:taji/shared/widgets/taji_drawer.dart';

class _FakeAuthController extends ChangeNotifier implements AuthController {
  @override
  AuthStatus status = AuthStatus.authenticated;

  @override
  TajiUser? user = const TajiUser(
    id: 1,
    email: 'admin@taji.test',
    firstName: 'German',
    lastName: 'Rojas',
    fullName: 'German Rojas',
    phone: '77712345',
    role: TajiRole(
      name: 'Administrador',
      slug: 'administrador',
      description: 'Admin del sistema',
      permissions: [
        'validate_visits',
        'operate_security_shifts',
        'view_security_shifts',
      ],
    ),
    activeTenant: TajiTenant(
      id: 1,
      name: 'Condominio Las Palmas',
      slug: 'las-palmas',
    ),
  );

  @override
  bool busy = false;

  @override
  String? error;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async => true;

  @override
  void clearError() {}

  @override
  Future<bool> requestPasswordReset(String email) async => true;
}

void main() {
  testWidgets('TajiDrawer renders web-style sidebar packages and tenant pill', (tester) async {
    tester.view.physicalSize = const Size(1080, 4500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/inicio',
      routes: [
        GoRoute(
          path: '/inicio',
          builder: (context, state) => const Scaffold(
            drawer: TajiDrawer(),
            body: Center(child: Text('Home Content')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => _FakeAuthController(),
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Verify brand logo and direct nav
    expect(find.text('taji'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);

    // Verify 5 package sections (matching Web sidebar)
    expect(find.text('Usuarios y Condominio'), findsOneWidget);
    expect(find.text('Seguridad y Accesos'), findsOneWidget);
    expect(find.text('Incidencias e IA'), findsOneWidget);
    expect(find.text('Activos y Mantenimiento'), findsOneWidget);
    expect(find.text('Servicios y Comunidad'), findsOneWidget);

    // Verify multi-tenant SaaS active condominium pill and slug
    expect(find.text('CONDOMINIO'), findsOneWidget);
    expect(find.text('Condominio Las Palmas'), findsOneWidget);
    expect(find.text('las-palmas'), findsOneWidget);

    // Verify mini-profile with user initials and role
    expect(find.text('German Rojas'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('GR'), findsOneWidget);

    // Verify sub-items inside expanded packages
    expect(find.text('Mi Condominio & SaaS'), findsOneWidget);
    expect(find.text('Pases QR de Visita'), findsOneWidget);
    expect(find.text('Turnos de seguridad'), findsOneWidget);
  });
}
