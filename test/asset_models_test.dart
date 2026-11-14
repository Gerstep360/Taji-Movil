import 'package:flutter_test/flutter_test.dart';
import 'package:taji/features/assets/models/asset_models.dart';

void main() {
  group('Asset model', () {
    test('deserializes from JSON', () {
      final json = {
        'id': 1,
        'code': 'ACT-001',
        'name': 'Bomba de agua',
        'description': 'Bomba para el tanque principal',
        'asset_type_name': 'Equipamiento',
        'sector_name': 'Azotea',
        'status': 'active',
        'qr_uuid': 'a1b2c3d4e5f6g7h8',
        'created_at': '2026-11-02T10:30:00Z',
        'brand': 'Pentair',
        'model': 'XB100',
        'serial_number': 'SN-123456',
      };

      final asset = Asset.fromJson(json);

      expect(asset.id, 1);
      expect(asset.code, 'ACT-001');
      expect(asset.name, 'Bomba de agua');
      expect(asset.assetTypeName, 'Equipamiento');
      expect(asset.status, 'active');
      expect(asset.qrUuid, 'a1b2c3d4e5f6g7h8');
    });

    test('handles nullable fields', () {
      final json = {
        'id': 2,
        'code': 'ACT-002',
        'name': 'Generador',
        'asset_type_name': 'Equipamiento',
        'status': 'maintenance',
        'qr_uuid': 'x1y2z3a4b5c6d7e8',
        'created_at': '2026-11-01T15:45:00Z',
      };

      final asset = Asset.fromJson(json);

      expect(asset.description, isNull);
      expect(asset.sectorName, isNull);
      expect(asset.brand, isNull);
      expect(asset.model, isNull);
      expect(asset.serialNumber, isNull);
    });
  });

  group('AssetHistory model', () {
    test('deserializes with all sections', () {
      final json = {
        'asset_id': 1,
        'incidents': [
          {
            'id': 101,
            'public_code': 'INC-001',
            'title': 'Falla de presión',
            'status': 'open',
            'created_at': '2026-11-01T09:00:00Z',
          },
        ],
        'work_orders': [
          {
            'id': 201,
            'public_code': 'WO-001',
            'title': 'Mantenimiento preventivo',
            'work_type': 'preventive',
            'status': 'completed',
            'scheduled_for': '2026-11-05T08:00:00Z',
            'completed_at': '2026-11-05T10:30:00Z',
            'created_at': '2026-10-28T12:00:00Z',
          },
        ],
        'maintenance_plans': [
          {
            'id': 301,
            'name': 'Revisión trimestral',
            'frequency_days': 90,
            'last_completed_at': '2026-10-15T08:00:00Z',
            'next_due_at': '2027-01-13T08:00:00Z',
            'is_active': true,
          },
        ],
      };

      final history = AssetHistory.fromJson(json);

      expect(history.assetId, 1);
      expect(history.incidents.length, 1);
      expect(history.incidents[0].title, 'Falla de presión');
      expect(history.workOrders.length, 1);
      expect(history.workOrders[0].status, 'completed');
      expect(history.maintenancePlans.length, 1);
      expect(history.maintenancePlans[0].isActive, true);
    });

    test('handles empty sections', () {
      final json = {
        'asset_id': 2,
      };

      final history = AssetHistory.fromJson(json);

      expect(history.assetId, 2);
      expect(history.incidents.isEmpty, true);
      expect(history.workOrders.isEmpty, true);
      expect(history.maintenancePlans.isEmpty, true);
    });
  });
}
