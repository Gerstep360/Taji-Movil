import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/token_store.dart';
import 'package:taji/features/management/module_catalog.dart';
import 'package:taji/features/management/module_repository.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_models.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_repository.dart';

class _MemoryTokens extends TokenStore {
  String? value, tenant;
  @override
  Future<String?> get access async => value;
  @override
  Future<String?> get tenantId async => tenant;
  @override
  Future<String?> get refresh async => null;
}

void main() {
  final base = Platform.environment['CU24_LIVE_URL'];
  test(
    'Flutter contra Django real: gestión, comunidad, reserva y PDF',
    () async {
      expect(base, 'http://localhost:18766');
      final tokens = _MemoryTokens();
      final client = ApiClient(tokenStore: tokens);
      client.dio.options.baseUrl = '$base/api/v1';
      addTearDown(() => client.dio.close());
      Future<void> login(String role) async {
        final data = await client.post<Map<String, dynamic>>(
          '/auth/login/',
          data: {
            'email': '$role@cu24.test',
            'password': 'OnlyLocal-CU24-123!',
            'client': 'mobile',
          },
        );
        tokens.value = (data!['tokens'] as Map)['access'] as String;
        final me = await client.get<Map<String, dynamic>>('/auth/me/');
        tokens.tenant = ((me!['user'] as Map)['active_tenant'] as Map)['id']
            .toString();
      }

      await login('administrador');
      final repository = ModuleRepository(client);
      for (final module in mobileModules.values) {
        expect(
          (await repository.list(module)).pages,
          greaterThanOrEqualTo(1),
          reason: module.endpoint,
        );
      }
      Future<ResourceRow> create(String key, ResourceRow data) =>
          repository.save(mobileModules[key]!, data);
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final sector = await create('sectors', {
        'code': 'S-$stamp',
        'name': 'Sector móvil',
        'sector_type': 'ZONE',
      });
      final unit = await create('units', {
        'code': 'U-$stamp',
        'sector': sector['id'],
        'unit_type': 'APARTMENT',
      });
      final resident = await create('residents', {
        'first_name': 'María',
        'last_name': 'Prueba',
        'document_number': stamp,
      });
      await create('resident-units', {
        'resident': resident['id'],
        'unit': unit['id'],
        'relation_type': 'OWNER',
        'start_date': '2026-01-01',
      });
      final staff = await create('staff', {
        'first_name': 'Pedro',
        'last_name': 'Prueba',
        'staff_type': 'MAINTENANCE',
      });
      await repository.save(mobileModules['staff']!, {
        'notes': 'Editado desde Flutter',
      }, original: staff);
      final area = await create('areas', {
        'name': 'Sala Flutter $stamp',
        'sector': sector['id'],
        'capacity': 15,
        'requires_approval': false,
      });
      await create('announcements', {
        'title': 'Aviso Flutter',
        'body': 'Texto de prueba',
        'audience': 'ALL',
        'status': 'PUBLISHED',
      });
      final assembly = await create('assemblies', {
        'title': 'Asamblea Flutter',
        'scheduled_at': DateTime.now()
            .add(const Duration(days: 7))
            .toUtc()
            .toIso8601String(),
      });
      await create('agreements', {
        'assembly': assembly['id'],
        'title': 'Acuerdo Flutter',
      });
      final reports = ReportsRepository(client);
      expect((await reports.catalog()).formats, contains('pdf'));
      final pdf = await reports.export(
        ReportQuery(
          source: 'incidents',
          columns: ['public_code'],
          filters: [],
          ordering: [],
        ),
        'pdf',
      );
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      await login('residente');
      final start = DateTime.now().add(const Duration(days: 3));
      final reservation = await create('reservations', {
        'common_area': area['id'],
        'start_at': start.toUtc().toIso8601String(),
        'end_at': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'purpose': 'Prueba nativa',
      });
      expect(reservation['status'], 'APPROVED');
      final cancelled = await repository.save(mobileModules['reservations']!, {
        'status': 'CANCELLED',
      }, original: reservation);
      expect(cancelled['status'], 'CANCELLED');
      expect(
        (await repository.list(mobileModules['announcements']!)).items,
        isNotEmpty,
      );
    },
    skip: base == null ? 'Requiere servidor efímero CU24_LIVE_URL.' : false,
  );
}
