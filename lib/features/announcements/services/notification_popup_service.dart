import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/models/notification_models.dart';
import '../data/announcements_repository.dart';
import '../widgets/announcement_popup_dialog.dart';

class NotificationPopupService {
  NotificationPopupService._();
  static final NotificationPopupService instance = NotificationPopupService._();

  final Set<int> _dismissedThisSession = <int>{};
  bool _isChecking = false;

  void resetSession() {
    _dismissedThisSession.clear();
  }

  Future<void> checkAndShowHighPriority(BuildContext context) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final apiClient = context.read<ApiClient>();
      final repo = AnnouncementsRepository(apiClient);

      final List<NotificationModel> unreadList = await repo.getNotifications(unreadOnly: true);

      final highPriorityPending = unreadList.where((n) {
        return n.isHighPriority && !n.isRead && !_dismissedThisSession.contains(n.id);
      }).toList();

      if (highPriorityPending.isEmpty || !context.mounted) {
        _isChecking = false;
        return;
      }

      final nextItem = highPriorityPending.first;

      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AnnouncementPopupDialog(
          notification: nextItem,
          onUnderstood: () async {
            await repo.markNotificationAsRead(nextItem.id);
            _dismissedThisSession.add(nextItem.id);
          },
          onDismissForSession: () {
            _dismissedThisSession.add(nextItem.id);
          },
        ),
      );

      _isChecking = false;

      // Si aún queda otro comunicado urgente pendiente en cola, mostrar el siguiente
      if (context.mounted) {
        final remaining = highPriorityPending.where((n) => !_dismissedThisSession.contains(n.id));
        if (remaining.isNotEmpty) {
          await checkAndShowHighPriority(context);
        }
      }
    } catch (_) {
      _isChecking = false;
    }
  }
}
