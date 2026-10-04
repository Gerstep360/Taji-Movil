import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/visitors/data/visit_qr_repository.dart';
import 'package:taji/features/visitors/models/visit_qr.dart';
import 'package:taji/features/visitors/state/visit_qr_controller.dart';
import 'package:taji/features/visitors/state/visit_qr_validation_controller.dart';

Map<String, dynamic> authorizationJson({
  String status = 'AUTHORIZED',
  String? qrExpiresAt,
}) => {
  'id': 12,
  'status': status,
  'status_display': 'Autorizada',
  'purpose': 'Almuerzo familiar',
  'visitor': {
    'id': 8,
    'first_name': 'Mario',
    'last_name': 'Gómez',
    'full_name': 'Mario Gómez',
    'document_type': 'CI',
    'document_number': '7766554',
  },
  'resident': {
    'id': 3,
    'full_name': 'Carlos Mendoza',
    'document_number': '5544332',
  },
  'unit_detail': {
    'id': 5,
    'code': 'A-101',
    'floor_label': 'Piso 3',
    'sector_name': 'Torre A',
  },
  'valid_from': '2026-10-03T15:00:00Z',
  'valid_until': '2026-10-03T21:00:00Z',
  'qr_uuid': '6f2a1b3c4d5e6f708192a3b4c5d6e7f8',
  'qr_expires_at': qrExpiresAt ?? '2026-10-03T20:00:00Z',
};

Map<String, dynamic> ticketJson({
  bool issued = true,
  bool active = true,
  String? payload = 'TAJI1.6f2a.token',
  int expiresInSeconds = 3600,
  bool rotated = false,
  String status = 'AUTHORIZED',
  String? qrExpiresAt,
}) => {
  'authorization': authorizationJson(status: status, qrExpiresAt: qrExpiresAt),
  'issued': issued,
  'active': active,
  'payload': payload,
  'expires_in_seconds': expiresInSeconds,
  'image_format': 'svg',
  'image_media_type': 'image/svg+xml',
  'image_base64': payload == null ? null : 'PHN2Zz4=',
  'rotated': rotated,
};

Map<String, dynamic> validationJson({
  bool valid = true,
  String reason = 'VALID',
  bool withAuthorization = true,
}) => {
  'valid': valid,
  'reason': reason,
  'message': 'Autorización de visita vigente. Ingreso permitido.',
  'checked_at': '2026-10-03T16:30:00Z',
  'authorization': withAuthorization
      ? authorizationJson(status: valid ? 'ACTIVE' : 'CANCELLED')
      : null,
  'access_event': {
    'id': 44,
    'event_type': valid ? 'ENTRY' : 'DENIED',
    'validation_method': 'QR',
    'validation_result': valid ? 'APPROVED' : 'REJECTED',
    'occurred_at': '2026-10-03T16:30:00Z',
  },
};

class _FakeVisitQrRepository implements VisitQrDataSource {
  VisitQrTicket? statusResponse;
  VisitQrTicket? generateResponse;
  VisitQrValidation? validationResponse;
  Object? throwOn;
  Object? throwOnReasons;

  int generateCalls = 0;
  bool? lastForce;
  int? lastTtl;
  String? lastToken;
  String? lastNotes;

  @override
  Future<VisitQrTicket> status(int authorizationId) async => _guard(() {
    if (statusResponse != null) return statusResponse!;
    return VisitQrTicket.fromJson(ticketJson(payload: null, active: false));
  });

  @override
  Future<VisitQrTicket> generate(
    int authorizationId, {
    int? ttlMinutes,
    bool force = false,
  }) async => _guard(() {
    generateCalls++;
    lastForce = force;
    lastTtl = ttlMinutes;
    return generateResponse ?? VisitQrTicket.fromJson(ticketJson());
  });

  @override
  Future<VisitQrValidation> validate({
    required String token,
    String? notes,
    String? deviceId,
  }) async => _guard(() {
    lastToken = token;
    lastNotes = notes;
    return validationResponse ?? VisitQrValidation.fromJson(validationJson());
  });

  @override
  Future<List<VisitQrRejectionReason>> rejectionReasons() async {
    final error = throwOnReasons;
    if (error != null) throw error;
    return [
      const VisitQrRejectionReason(
        value: 'QR_EXPIRED',
        message: 'El código QR venció. Solicita un QR nuevo al residente.',
      ),
    ];
  }

  T _guard<T>(T Function() body) {
    final error = throwOn;
    if (error is TajiError) throw error;
    if (error != null) throw error;
    return body();
  }
}

class TajiError extends ApiFailure {
  const TajiError() : super(code: 'boom', message: 'falló');
}

void main() {
  group('VisitQrTicket', () {
    test('lee la respuesta de emisión con su contenido y vigencia', () {
      final ticket = VisitQrTicket.fromJson(ticketJson(expiresInSeconds: 900));

      expect(ticket.issued, isTrue);
      expect(ticket.active, isTrue);
      expect(ticket.hasPayload, isTrue);
      expect(ticket.payload, 'TAJI1.6f2a.token');
      expect(ticket.expiresInSeconds, 900);
      expect(ticket.authorization.visitorName, 'Mario Gómez');
      expect(ticket.authorization.unitLabel, 'Torre A · A-101 · Piso 3');
    });

    test('la consulta nunca trae contenido y el token queda vacío', () {
      final ticket = VisitQrTicket.fromJson(ticketJson(payload: null));

      expect(ticket.issued, isTrue);
      expect(ticket.hasPayload, isFalse);
      expect(ticket.payload, isNull);
    });

    test('mapea el estado terminal para impedir el ingreso', () {
      final ticket = VisitQrTicket.fromJson(ticketJson(status: 'CANCELLED'));

      expect(ticket.authorization.status, VisitAuthorizationStatus.cancelled);
      expect(ticket.authorization.status.isTerminal, isTrue);
      expect(ticket.authorization.status.allowsEntry, isFalse);
    });

    test('tolera fechas nulas o con formato inesperado', () {
      final json = authorizationJson()
        ..remove('valid_until')
        ..['qr_expires_at'] = 'no-es-una-fecha';

      final authorization = VisitQrAuthorization.fromJson(json);

      expect(authorization.validUntil, isNull);
      expect(authorization.qrExpiresAt, isNull);
    });
  });

  group('VisitQrValidation', () {
    test('un ingreso aprobado trae autorización y evento de acceso', () {
      final result = VisitQrValidation.fromJson(validationJson());

      expect(result.valid, isTrue);
      expect(result.hasAuthorization, isTrue);
      expect(result.visitorName, 'Mario Gómez');
      expect(result.residentName, 'Carlos Mendoza');
      expect(result.accessEvent?.eventLabel, 'Entrada');
      expect(result.accessEvent?.resultLabel, 'Aprobado');
      expect(result.requiresNewQr, isFalse);
    });

    test('un QR desconocido no trae autorización y no exige reimprimir', () {
      final result = VisitQrValidation.fromJson(
        validationJson(
          valid: false,
          reason: 'NOT_FOUND',
          withAuthorization: false,
        ),
      );

      expect(result.valid, isFalse);
      expect(result.hasAuthorization, isFalse);
      expect(result.visitorName, '');
      expect(result.reasonLabel, 'QR desconocido');
    });

    test('un QR vencido pide uno nuevo al residente', () {
      final result = VisitQrValidation.fromJson(
        validationJson(valid: false, reason: 'QR_EXPIRED'),
      );

      expect(result.requiresNewQr, isTrue);
      expect(result.reasonLabel, 'QR vencido');
    });
  });

  group('VisitQrController', () {
    test('genera el QR y deja el payload listo para mostrar', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrController(repository, authorizationId: 12);
      addTearDown(controller.dispose);

      final issued = await controller.generate(ttlMinutes: 240);

      expect(issued, isTrue);
      expect(controller.hasQrImage, isTrue);
      expect(controller.payload, 'TAJI1.6f2a.token');
      expect(repository.lastTtl, 240);
      expect(repository.lastForce, isFalse);
    });

    test('rotar el QR envía force para invalidar el código anterior', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrController(repository, authorizationId: 12);
      addTearDown(controller.dispose);

      await controller.generate(force: true);

      expect(repository.lastForce, isTrue);
    });

    test(
      'exige rotar cuando hay un QR vigente que no se puede recuperar',
      () async {
        final repository = _FakeVisitQrRepository()
          ..statusResponse = VisitQrTicket.fromJson(ticketJson(payload: null));
        final controller = VisitQrController(repository, authorizationId: 12);
        addTearDown(controller.dispose);

        await controller.load();

        // El backend solo guarda el hash del token: no hay forma de mostrar un QR
        // emitido desde otro dispositivo, así que la pantalla ofrece rotarlo.
        expect(controller.needsRotation, isTrue);
        expect(controller.hasQrImage, isFalse);
      },
    );

    test(
      'conserva el payload en memoria ante una emisión idempotente',
      () async {
        final repository = _FakeVisitQrRepository();
        final controller = VisitQrController(repository, authorizationId: 12);
        addTearDown(controller.dispose);

        await controller.generate();
        // Segunda emisión sin `force`: llega 200 con `payload: null`.
        repository.generateResponse = VisitQrTicket.fromJson(
          ticketJson(payload: null, rotated: false),
        );
        await controller.generate();

        expect(controller.hasQrImage, isTrue);
        expect(controller.needsRotation, isFalse);
      },
    );

    test('un QR ya vencido no se considera utilizable', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrController(repository, authorizationId: 12);
      addTearDown(controller.dispose);

      repository.generateResponse = VisitQrTicket.fromJson(
        ticketJson(
          active: false,
          expiresInSeconds: 0,
          qrExpiresAt: DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toUtc()
              .toIso8601String(),
        ),
      );
      await controller.generate();

      expect(controller.isExpired, isTrue);
      expect(controller.isUsable, isFalse);
      expect(controller.remainingSeconds, 0);
    });

    test('el estado terminal de la visita bloquea la emisión', () async {
      final repository = _FakeVisitQrRepository()
        ..statusResponse = VisitQrTicket.fromJson(
          ticketJson(status: 'CANCELLED', active: false),
        );
      final controller = VisitQrController(repository, authorizationId: 12);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isBlockedByStatus, isTrue);
    });

    test('propaga el error del servidor sin dejar estado a medias', () async {
      final repository = _FakeVisitQrRepository()..throwOn = const TajiError();
      final controller = VisitQrController(repository, authorizationId: 12);
      addTearDown(controller.dispose);

      final issued = await controller.generate();

      expect(issued, isFalse);
      expect(controller.error, 'falló');
      expect(controller.generating, isFalse);
    });
  });

  group('VisitQrValidationController', () {
    test('un rechazo es un veredicto, no un error', () async {
      final repository = _FakeVisitQrRepository()
        ..validationResponse = VisitQrValidation.fromJson(
          validationJson(valid: false, reason: 'VISIT_CANCELLED'),
        );
      final controller = VisitQrValidationController(repository);
      addTearDown(controller.dispose);

      final answered = await controller.validate('TAJI1.6f2a.token');

      // El backend responde 200 con `valid: false`; tratarlo como fallo
      // impediría mostrarle al guardia por qué se denegó el ingreso.
      expect(answered, isTrue);
      expect(controller.error, isNull);
      expect(controller.result?.valid, isFalse);
      expect(controller.result?.reasonLabel, 'Visita cancelada');
      expect(controller.deniedCount, 1);
      expect(controller.approvedCount, 0);
    });

    test('ignora repetir el mismo token sin pulsar "escanear otro"', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrValidationController(repository);
      addTearDown(controller.dispose);

      await controller.validate('TAJI1.6f2a.token');
      await controller.validate('TAJI1.6f2a.token');

      // Reenviarlo crearía un segundo evento de acceso por el mismo ingreso.
      expect(controller.history, hasLength(1));
      expect(controller.approvedCount, 1);
    });

    test('volver a escanear permite validar el siguiente código', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrValidationController(repository);
      addTearDown(controller.dispose);

      await controller.validate('primero');
      controller.scanAgain();
      expect(controller.isPaused, isFalse);

      await controller.validate('segundo');

      expect(controller.history, hasLength(2));
      expect(controller.approvedCount, 2);
    });

    test('descarta el token en blanco antes de llamar al servidor', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrValidationController(repository);
      addTearDown(controller.dispose);

      expect(await controller.validate('   '), isFalse);
      expect(repository.lastToken, isNull);
    });

    test(
      'un fallo de red sí se reporta como error y no como veredicto',
      () async {
        final repository = _FakeVisitQrRepository()
          ..throwOn = const TajiError();
        final controller = VisitQrValidationController(repository);
        addTearDown(controller.dispose);

        final answered = await controller.validate('TAJI1.6f2a.token');

        expect(answered, isFalse);
        expect(controller.error, 'falló');
        expect(controller.result, isNull);
      },
    );

    test('acota el historial de la sesión', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrValidationController(repository);
      addTearDown(controller.dispose);

      for (
        var index = 0;
        index < VisitQrValidationController.historyLimit + 5;
        index++
      ) {
        await controller.validate('token-$index');
        controller.scanAgain();
      }

      expect(
        controller.history,
        hasLength(VisitQrValidationController.historyLimit),
      );
    });

    test('usa el catálogo del backend para el texto del motivo', () async {
      final repository = _FakeVisitQrRepository();
      final controller = VisitQrValidationController(repository);
      addTearDown(controller.dispose);

      await controller.loadReasons();

      expect(controller.reasons, hasLength(1));
      expect(
        controller.messageFor('qr_expired'),
        'El código QR venció. Solicita un QR nuevo al residente.',
      );
    });

    test('un fallo al bajar el catálogo no impide escanear', () async {
      final repository = _FakeVisitQrRepository()
        ..throwOnReasons = const TajiError();
      final controller = VisitQrValidationController(repository);
      addTearDown(controller.dispose);

      await controller.loadReasons();

      expect(controller.reasons, isEmpty);
      expect(controller.loadingReasons, isFalse);
      expect(await controller.validate('TAJI1.6f2a.token'), isTrue);
    });
  });

  group('TajiUserAccess', () {
    TajiUser userWithRole(String slug, List<String> permissions) => TajiUser(
      id: 1,
      email: 'correo@taji.test',
      firstName: 'Luis',
      lastName: 'Roca',
      fullName: 'Luis Roca',
      phone: '',
      role: TajiRole(
        slug: slug,
        name: slug,
        description: '',
        permissions: permissions,
      ),
    );

    test('el personal de seguridad puede validar QR en portería', () {
      final guard = userWithRole('seguridad', [
        'validate_visits',
        'register_entry_exit',
      ]);

      expect(guard.canValidateVisits, isTrue);
      // No emite QR: su rol es validar, no autorizar.
      expect(guard.canIssueVisitQr, isFalse);
    });

    test('la administración puede validar y emitir', () {
      final admin = userWithRole('administrador', [
        'manage_visits',
        'validate_visits',
        'register_visits',
      ]);

      expect(admin.canValidateVisits, isTrue);
      expect(admin.canIssueVisitQr, isTrue);
      expect(admin.isAdmin, isTrue);
    });

    test('un residente emite su QR pero no valida en portería', () {
      final resident = userWithRole('residente', [
        'register_visits',
        'view_announcements',
      ]);

      expect(resident.canIssueVisitQr, isTrue);
      expect(resident.canValidateVisits, isFalse);
    });

    test('un usuario sin rol no alcanza para ninguna de las dos acciones', () {
      final user = const TajiUser(
        id: 1,
        email: 'correo@taji.test',
        firstName: 'Ana',
        lastName: 'Pérez',
        fullName: 'Ana Pérez',
        phone: '',
      );

      expect(user.canValidateVisits, isFalse);
      expect(user.canIssueVisitQr, isFalse);
    });
  });
}
