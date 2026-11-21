import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/notification_models.dart';

abstract class AnnouncementsDataSource {
  Future<List<AnnouncementModel>> getAnnouncements({String? audience, String? priority});
  Future<List<NotificationModel>> getNotifications({bool? unreadOnly});
  Future<int> getUnreadNotificationCount();
  Future<void> markNotificationAsRead(int id);
  Future<void> markAllNotificationsAsRead();
  Future<void> registerDeviceToken({required String token, required String platform});
}

class AnnouncementsRepository implements AnnouncementsDataSource {
  const AnnouncementsRepository(this._api);

  final ApiClient _api;

  Future<T> _request<T>(Future<T> Function() action, String fallback) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: fallback);
    } on FormatException {
      throw const ApiFailure(
        code: 'format_error',
        message: 'Formato de respuesta inesperado.',
      );
    } on TypeError {
      throw const ApiFailure(
        code: 'type_error',
        message: 'Error al interpretar los datos del servidor.',
      );
    }
  }

  @override
  Future<List<AnnouncementModel>> getAnnouncements({String? audience, String? priority}) =>
      _request(() async {
        final queryParams = <String, dynamic>{};
        if (audience != null && audience.isNotEmpty) queryParams['audience'] = audience;
        if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;

        final data = await _api.get<dynamic>(
          ApiEndpoints.announcements.collection,
          query: queryParams.isNotEmpty ? queryParams : null,
        );

        if (data == null) return [];
        final rawList = data is Map<String, dynamic>
            ? (data['results'] as List<dynamic>? ?? [])
            : (data is List ? data : []);

        return rawList
            .map((item) => AnnouncementModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }, 'No pudimos cargar los comunicados.');

  @override
  Future<List<NotificationModel>> getNotifications({bool? unreadOnly}) =>
      _request(() async {
        final queryParams = <String, dynamic>{};
        if (unreadOnly == true) queryParams['unread'] = 'true';

        final data = await _api.get<dynamic>(
          ApiEndpoints.notifications.collection,
          query: queryParams.isNotEmpty ? queryParams : null,
        );

        if (data == null) return [];
        final rawList = data is Map<String, dynamic>
            ? (data['results'] as List<dynamic>? ?? [])
            : (data is List ? data : []);

        return rawList
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }, 'No pudimos cargar las notificaciones.');

  @override
  Future<int> getUnreadNotificationCount() => _request(() async {
        final data = await _api.get<Map<String, dynamic>>(
          ApiEndpoints.notifications.unreadCount,
        );
        return (data?['unread_count'] as num?)?.toInt() ?? 0;
      }, 'No pudimos obtener el recuento de notificaciones.');

  @override
  Future<void> markNotificationAsRead(int id) => _request(() async {
        await _api.post<Map<String, dynamic>>(
          ApiEndpoints.notifications.markRead(id),
        );
      }, 'No pudimos marcar la notificación como leída.');

  @override
  Future<void> markAllNotificationsAsRead() => _request(() async {
        await _api.post<Map<String, dynamic>>(
          ApiEndpoints.notifications.markAllRead,
        );
      }, 'No pudimos marcar todas las notificaciones como leídas.');

  @override
  Future<void> registerDeviceToken({required String token, required String platform}) =>
      _request(() async {
        await _api.post<Map<String, dynamic>>(
          ApiEndpoints.notifications.devices,
          data: {
            'token': token,
            'platform': platform,
            'is_active': true,
          },
        );
      }, 'No pudimos registrar el dispositivo para notificaciones push.');
}
