import 'package:flutter/foundation.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/notification_models.dart';
import '../data/announcements_repository.dart';

class AnnouncementsController extends ChangeNotifier {
  AnnouncementsController(this._dataSource);

  final AnnouncementsDataSource _dataSource;

  List<AnnouncementModel> _announcements = [];
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  String? _selectedAudience;

  List<AnnouncementModel> get announcements => _announcements;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedAudience => _selectedAudience;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _dataSource.getAnnouncements(audience: _selectedAudience),
        _dataSource.getNotifications(),
        _dataSource.getUnreadNotificationCount(),
      ]);

      _announcements = results[0] as List<AnnouncementModel>;
      _notifications = results[1] as List<NotificationModel>;
      _unreadCount = results[2] as int;
    } on ApiFailure catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Ocurrió un error inesperado al cargar la información.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterByAudience(String? audience) {
    if (_selectedAudience == audience) return;
    _selectedAudience = audience;
    loadAll();
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _dataSource.markNotificationAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final current = _notifications[index];
        _notifications[index] = NotificationModel(
          id: current.id,
          userId: current.userId,
          notificationType: current.notificationType,
          title: current.title,
          message: current.message,
          resourceType: current.resourceType,
          resourceId: current.resourceId,
          sentAt: current.sentAt,
          readAt: DateTime.now(),
          createdAt: current.createdAt,
        );
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    } catch (_) {
      // Ignorar fallo de sincronización en UI
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _dataSource.markAllNotificationsAsRead();
      final now = DateTime.now();
      _notifications = _notifications.map((n) {
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
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}
