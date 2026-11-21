import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/domain/models/notification_models.dart';
import 'package:taji/features/announcements/widgets/announcement_popup_dialog.dart';

void main() {
  group('NotificationModel JSON & Priority Parsing', () {
    test('parsea prioridad y audiencia correctamente desde el JSON', () {
      final json = {
        'id': 105,
        'user_id': 3,
        'notification_type': 'ANNOUNCEMENT',
        'title': 'Corte Urgente de Luz',
        'message': 'Corte de energía por mantenimiento.',
        'resource_type': 'announcement',
        'resource_id': '10',
        'priority': 'HIGH',
        'audience': 'RESIDENTS',
        'sent_at': '2026-11-21T18:00:00Z',
        'read_at': null,
        'created_at': '2026-11-21T18:00:00Z',
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, 105);
      expect(model.priority, 'HIGH');
      expect(model.audience, 'RESIDENTS');
      expect(model.isHighPriority, isTrue);
      expect(model.isRead, isFalse);
    });

    test('asigna valores por defecto si prioridad no está presente', () {
      final json = {
        'id': 106,
        'user_id': 3,
        'notification_type': 'ANNOUNCEMENT',
        'title': 'Aviso Normal',
        'message': 'Mensaje general.',
        'sent_at': null,
        'read_at': null,
        'created_at': '2026-11-21T18:00:00Z',
      };

      final model = NotificationModel.fromJson(json);

      expect(model.priority, 'NORMAL');
      expect(model.isHighPriority, isFalse);
    });
  });

  group('AnnouncementPopupDialog Widget', () {
    final sampleNotif = NotificationModel(
      id: 201,
      userId: 5,
      notificationType: 'ANNOUNCEMENT',
      title: 'Mantenimiento del Tanque de Agua',
      message: 'El suministro de agua será suspendido de 08:00 a 12:00.',
      resourceType: 'announcement',
      resourceId: '7',
      priority: 'HIGH',
      audience: 'RESIDENTS',
      sentAt: DateTime.parse('2026-11-21T12:00:00Z'),
      readAt: null,
      createdAt: DateTime.parse('2026-11-21T12:00:00Z'),
    );

    testWidgets('renderiza el diálogo con título, contenido y badge de prioridad', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementPopupDialog(
              notification: sampleNotif,
              onUnderstood: () async {},
              onDismissForSession: () {},
            ),
          ),
        ),
      );

      expect(find.text('Mantenimiento del Tanque de Agua'), findsOneWidget);
      expect(find.textContaining('suministro de agua será suspendido'), findsOneWidget);
      expect(find.text('Prioridad HIGH'), findsOneWidget);
      expect(find.text('Audiencia: RESIDENTS'), findsOneWidget);
      expect(find.text('Ver después'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);
    });

    testWidgets('acciona onDismissForSession al presionar "Ver después"', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementPopupDialog(
              notification: sampleNotif,
              onUnderstood: () async {},
              onDismissForSession: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ver después'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('acciona onUnderstood al presionar "Entendido"', (tester) async {
      bool understoodCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementPopupDialog(
              notification: sampleNotif,
              onUnderstood: () async {
                understoodCalled = true;
              },
              onDismissForSession: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Entendido'));
      await tester.pump();

      expect(understoodCalled, isTrue);
    });
  });
}
