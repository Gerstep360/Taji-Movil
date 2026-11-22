import '../auth/models/taji_user.dart';

/// CU27: quién puede usar la pantalla de reservas (mismos códigos RBAC que el backend).
extension ReservationAccess on TajiUser {
  bool get canUseReservations =>
      isAdmin || hasPermission('reserve_areas') || hasPermission('manage_reservations');
}
