import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/features/visitors/data/visit_qr_repository.dart';
import 'package:taji/features/visitors/models/visit_qr.dart';
import 'package:taji/features/visitors/screens/visit_qr_screen.dart';

Map<String, dynamic> _authorizationJson(
  String status, {
  int remainingSeconds = 0,
}) => {
  'id': 12,
  'status': status,
  'status_display': 'Autorizada',
  'purpose': 'Almuerzo familiar con/parientes de la familia Gómez Fernández',
  'visitor': {
    'id': 8,
    'first_name': 'Mario',
    'last_name': 'Gómez',
    'full_name': 'Mario Gómez',
    'document_type': 'CI',
    'document_number': '7766554',
  },
  'resident': {'id': 3, 'full_name': 'Carlos Mendoza'},
  'unit_detail': {
    'id': 5,
    'code': 'A-101',
    'floor_label': 'Piso 3',
    'sector_name': 'Torre A',
  },
  'valid_from': '2026-10-03T15:00:00Z',
  'valid_until': '2026-10-03T21:00:00Z',
  'qr_uuid': '6f2a1b3c4d5e6f708192a3b4c5d6e7f8',
  // El backend manda la vigencia en valor absoluto, así que la fecha se ancla
  // al momento del test: si fuera fija, el reloj de la pantalla la daría por
  // vencida y las aserciones dependerían del día en que se corra la suite.
  'qr_expires_at': DateTime.now()
      .toUtc()
      .add(Duration(seconds: remainingSeconds))
      .toIso8601String(),
};

Map<String, dynamic> _ticketJson({
  String status = 'AUTHORIZED',
  bool issued = false,
  bool active = false,
  String? payload,
  int expiresInSeconds = 0,
}) => {
  'authorization': _authorizationJson(
    status,
    remainingSeconds: expiresInSeconds,
  ),
  'issued': issued,
  'active': active,
  'payload': payload,
  'expires_in_seconds': expiresInSeconds,
};

/// Reloj de la cuenta regresiva, p. ej. `01:00:00`.
Finder _clock() => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
);

/// Un QR vivo y recién emitido es lo que devuelve `generate` por defecto.
Map<String, dynamic> _freshTicketJson({String payload = 'TAJI1.a.b'}) =>
    _ticketJson(
      issued: true,
      active: true,
      payload: payload,
      expiresInSeconds: 3600,
    );

class _FakeVisitQrRepository implements VisitQrDataSource {
  _FakeVisitQrRepository({
    this.statusTicket,
    this.generatedTicket,
    this.throwOn,
  });

  VisitQrTicket? statusTicket;
  VisitQrTicket? generatedTicket;
  Object? throwOn;

  @override
  Future<VisitQrTicket> status(int authorizationId) async {
    final error = throwOn;
    if (error != null) throw error;
    return statusTicket ?? VisitQrTicket.fromJson(_ticketJson());
  }

  @override
  Future<VisitQrTicket> generate(
    int authorizationId, {
    int? ttlMinutes,
    bool force = false,
  }) async {
    final error = throwOn;
    if (error != null) throw error;
    return generatedTicket ?? VisitQrTicket.fromJson(_freshTicketJson());
  }

  @override
  Future<VisitQrValidation> validate({
    required String token,
    String? notes,
    String? deviceId,
  }) async => throw const ApiFailure(code: 'x', message: 'no usado');

  @override
  Future<List<VisitQrRejectionReason>> rejectionReasons() async => const [];
}

/// Monta la pantalla en un tamaño de teléfono Android y verifica que nada se
/// desborde. Los textos largos en español son la causa habitual de overflow.
Widget _app(Widget child, VisitQrDataSource repository) => MaterialApp(
  theme: buildTajiTheme(),
  home: Provider<VisitQrDataSource>.value(value: repository, child: child),
);

void main() {
  // Un teléfono pequeño es donde antes aparecían los desbordes.
  Future<void> pumpScreen(
    WidgetTester tester,
    VisitQrDataSource repository,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(const VisitQrScreen(authorizationId: 12), repository),
    );
    await tester.pumpAndSettle();
  }

  // El cuerpo es una lista larga: los botones quedan por debajo del pliegue, y
  // una `ListView` no construye lo que no ve. Hay que traerlos a la vista antes
  // de buscarlos.
  Future<void> scrollTo(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 180);
    await tester.pumpAndSettle();
  }

  Future<void> tapAfterScroll(WidgetTester tester, String label) async {
    await scrollTo(tester, label);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('emite el QR solo al abrir la pantalla, sin pulsar nada', (
    tester,
  ) async {
    await pumpScreen(tester, _FakeVisitQrRepository());

    // Antes habia que pulsar "Generar QR"; ahora la pantalla lo pide sola al
    // cargar, que es como la usa el residente de verdad.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('QR vigente'), findsOneWidget);
  });

  testWidgets('un QR ajeno vigente no se puede recuperar: hay que rotarlo', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _FakeVisitQrRepository(
        statusTicket: VisitQrTicket.fromJson(
          // El backend sabe que hay un QR vigente pero responde `payload: null`:
          // solo guarda el hash, así que el contenido no se puede volver a leer.
          _ticketJson(issued: true, active: true, expiresInSeconds: 3600),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('no se puede recuperar'), findsOneWidget);

    await tapAfterScroll(tester, 'Generar QR');

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('QR vigente'), findsOneWidget);
  });

  testWidgets('muestra el código y descuenta la vigencia en pantalla', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _FakeVisitQrRepository(
        statusTicket: VisitQrTicket.fromJson(
          _ticketJson(issued: true, active: true, expiresInSeconds: 3600),
        ),
      ),
    );

    await tapAfterScroll(tester, 'Generar QR');

    expect(find.textContaining('Vigencia restante:'), findsOneWidget);
    expect(_clock(), findsOneWidget);
    // Un código vigente se puede compartir y además se puede rotar.
    await scrollTo(tester, 'Copiar');
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Rotar'), findsOneWidget);
  });

  testWidgets('el QR vencido se muestra atenuado y no se puede compartir', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _FakeVisitQrRepository(
        statusTicket: VisitQrTicket.fromJson(
          _ticketJson(issued: true, active: true, expiresInSeconds: 3600),
        ),
        generatedTicket: VisitQrTicket.fromJson(
          _ticketJson(
            issued: true,
            active: false,
            payload: 'TAJI1.a.b',
            expiresInSeconds: 0,
          ),
        ),
      ),
    );

    await tapAfterScroll(tester, 'Generar QR');

    expect(find.text('QR vencido'), findsOneWidget);
    expect(find.text('Código vencido'), findsOneWidget);
    expect(find.text('Muestra este código en portería'), findsNothing);
    // Vencido no hay código que compartir, pero sí se puede pedir uno nuevo.
    await scrollTo(tester, 'Generar QR nuevo');
    expect(find.text('Copiar'), findsNothing);
  });

  testWidgets('una visita cancelada no ofrece emitir QR', (tester) async {
    await pumpScreen(
      tester,
      _FakeVisitQrRepository(
        statusTicket: VisitQrTicket.fromJson(_ticketJson(status: 'CANCELLED')),
      ),
    );

    expect(find.textContaining('cancelada'), findsOneWidget);
    expect(find.text('Generar QR'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('un fallo de carga muestra el mensaje y permite reintentar', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _FakeVisitQrRepository(
        throwOn: const ApiFailure(code: 'net', message: 'Sin conexión.'),
      ),
    );

    expect(find.text('Sin conexión.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('el detalle de la visita cabe sin desbordarse', (tester) async {
    await pumpScreen(
      tester,
      _FakeVisitQrRepository(
        statusTicket: VisitQrTicket.fromJson(
          _ticketJson(issued: true, active: true, expiresInSeconds: 5400),
        ),
      ),
    );

    await tapAfterScroll(tester, 'Generar QR');
    await scrollTo(tester, 'Datos de la visita');

    expect(find.text('Mario Gómez'), findsWidgets);
    expect(find.textContaining('A-101'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
