import 'package:flutter_test/flutter_test.dart';
import 'package:taji/domain/models/notification_models.dart';
import 'package:taji/features/announcements/data/announcements_repository.dart';
import 'package:taji/features/announcements/state/announcements_controller.dart';

class FakeAnnouncementsDataSource implements AnnouncementsDataSource {
  List<AnnouncementModel> announcementsData = [
    AnnouncementModel(
      id: 1,
      createdByUserId: 1,
      title: 'Aviso de Mantenimiento',
      body: 'Corte de agua temporal.',
      audience: 'ALL',
      priority: 'HIGH',
      publishedAt: DateTime.parse('2026-11-21T10:00:00Z'),
      expiresAt: null,
      status: 'PUBLISHED',
      createdAt: DateTime.parse('2026-11-21T09:00:00Z'),
      updatedAt: DateTime.parse('2026-11-21T10:00:00Z'),
    ),
    AnnouncementModel(
      id: 2,
      createdByUserId: 1,
      title: 'Aviso Solo Residentes',
      body: 'Asamblea general.',
      audience: 'RESIDENTS',
      priority: 'NORMAL',
      publishedAt: DateTime.parse('2026-11-21T11:00:00Z'),
      expiresAt: null,
      status: 'PUBLISHED',
      createdAt: DateTime.parse('2026-11-21T10:00:00Z'),
      updatedAt: DateTime.parse('2026-11-21T11:00:00Z'),
    ),
  ];

  List<NotificationModel> notificationsData = [
    NotificationModel(
      id: 101,
      userId: 5,
      notificationType: 'ANNOUNCEMENT',
      title: 'Nuevo Aviso',
      message: 'Corte de agua temporal.',
      resourceType: 'announcement',
      resourceId: '1',
      sentAt: DateTime.parse('2026-11-21T10:00:00Z'),
      readAt: null,
      createdAt: DateTime.parse('2026-11-21T10:00:00Z'),
    ),
    NotificationModel(
      id: 102,
      userId: 5,
      notificationType: 'ANNOUNCEMENT',
      title: 'Segundo Aviso',
      message: 'Detalle de asamblea.',
      resourceType: 'announcement',
      resourceId: '2',
      sentAt: DateTime.parse('2026-11-21T11:00:00Z'),
      readAt: null,
      createdAt: DateTime.parse('2026-11-21T11:00:00Z'),
    ),
  ];

  @override
  Future<List<AnnouncementModel>> getAnnouncements({String? audience, String? priority}) async {
    if (audience != null) {
      return announcementsData.where((a) => a.audience == audience).toList();
    }
    return announcementsData;
  }

  @override
  Future<List<NotificationModel>> getNotifications({bool? unreadOnly}) async {
    if (unreadOnly == true) {
      return notificationsData.where((n) => n.readAt == null).toList();
    }
    return notificationsData;
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    return notificationsData.where((n) => n.readAt == null).length;
  }

  @override
  Future<void> markNotificationAsRead(int id) async {
    final idx = notificationsData.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final old = notificationsData[idx];
      notificationsData[idx] = NotificationModel(
        id: old.id,
        userId: old.userId,
        notificationType: old.notificationType,
        title: old.title,
        message: old.message,
        resourceType: old.resourceType,
        resourceId: old.resourceId,
        sentAt: old.sentAt,
        readAt: DateTime.now(),
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<void> markAllNotificationsAsRead() async {
    final now = DateTime.now();
    notificationsData = notificationsData.map((n) {
      return NotificationModel(
        id: n.id,
        userId: n.userId,
        notificationType: n.notificationType,
        title: n.title,
        message: n.message,
        resourceType: n.resourceType,
        resourceId: n.resourceId,
        sentAt: n.sentAt,
        readAt: n.readAt ?? now,
        createdAt: n.createdAt,
      );
    }).toList();
  }

  @override
  Future<void> registerDeviceToken({required String token, required String platform}) async {}
}

void main() {
  group('CU28 / T123 — Centro de Comunicados y Notificaciones Móvil', () {
    late FakeAnnouncementsDataSource dataSource;
    late AnnouncementsController controller;

    setUp(() {
      dataSource = FakeAnnouncementsDataSource();
      controller = AnnouncementsController(dataSource);
    });

    test('Carga comunicados, notificaciones y recuento de no leídas correctamente', () async {
      await controller.loadAll();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(controller.announcements.length, equals(2));
      expect(controller.notifications.length, equals(2));
      expect(controller.unreadCount, equals(2));
    });

    test('Filtra comunicados por audiencia correctamente', () async {
      controller.filterByAudience('RESIDENTS');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.announcements.length, equals(1));
      expect(controller.announcements.first.audience, equals('RESIDENTS'));
    });

    test('Marca notificación individual como leída y actualiza el contador', () async {
      await controller.loadAll();
      expect(controller.unreadCount, equals(2));

      await controller.markAsRead(101);

      expect(controller.unreadCount, equals(1));
      expect(controller.notifications.firstWhere((n) => n.id == 101).readAt, isNotNull);
      expect(controller.notifications.firstWhere((n) => n.id == 102).readAt, isNull);
    });

    test('Marca todas las notificaciones como leídas y pone el contador en cero', () async {
      await controller.loadAll();
      expect(controller.unreadCount, equals(2));

      await controller.markAllAsRead();

      expect(controller.unreadCount, equals(0));
      expect(controller.notifications.every((n) => n.readAt != null), isTrue);
    });
  });
}
