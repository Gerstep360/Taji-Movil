import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/taji_theme.dart';
import '../../features/auth/models/taji_user.dart';
import '../../features/auth/state/auth_controller.dart';
import 'taji_logo.dart';

class TajiDrawer extends StatefulWidget {
  const TajiDrawer({super.key});

  @override
  State<TajiDrawer> createState() => _TajiDrawerState();
}

class _TajiDrawerState extends State<TajiDrawer> {
  // Estado de acordeón por paquete: Paquete 1 y 2 abiertos por defecto, igual que en Web
  final Set<String> _expandedPackages = {'paquete1', 'paquete2'};

  void _togglePackage(String packageId) {
    setState(() {
      if (_expandedPackages.contains(packageId)) {
        _expandedPackages.remove(packageId);
      } else {
        _expandedPackages.add(packageId);
      }
    });
  }

  bool _isExpanded(String packageId) => _expandedPackages.contains(packageId);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final roleName = user?.role?.name ?? 'Residente';
    final topPadding = MediaQuery.of(context).padding.top;
    final currentLocation = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ASIDE HEADER (Brand + Close Button, igual que Web)
            Container(
              padding: EdgeInsets.fromLTRB(20, topPadding + 14, 16, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const TajiLogo(light: false),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // NAV SCROLLABLE (Igual que Web main-layout)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                children: [
                  // INICIO DIRECTO
                  _DirectNavItem(
                    icon: Icons.home_rounded,
                    label: 'Inicio',
                    isActive: currentLocation == AppRoute.home.path,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoute.home.path);
                    },
                  ),

                  const SizedBox(height: 8),

                  // PAQUETE 1: USUARIOS Y CONDOMINIO
                  _PackageAccordion(
                    id: 'paquete1',
                    title: 'Usuarios y Condominio',
                    icon: Icons.people_outline_rounded,
                    isExpanded: _isExpanded('paquete1'),
                    onToggle: () => _togglePackage('paquete1'),
                    activeCount: 1,
                    items: [
                      const _DrawerSubItem(
                        label: 'Roles y Permisos',
                        icon: Icons.admin_panel_settings_outlined,
                        isAvailable: false,
                      ),
                      const _DrawerSubItem(
                        label: 'Personal del Condominio',
                        icon: Icons.badge_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Mi Condominio & SaaS',
                        icon: Icons.business_outlined,
                        isAvailable: true,
                        onTap: () {
                          Navigator.pop(context);
                          _showCondominiumInfo(context, user);
                        },
                      ),
                      const _DrawerSubItem(
                        label: 'Sectores y Unidades',
                        icon: Icons.grid_view_outlined,
                        isAvailable: false,
                      ),
                      const _DrawerSubItem(
                        label: 'Residentes y Copropietarios',
                        icon: Icons.people_outline,
                        isAvailable: false,
                      ),
                      const _DrawerSubItem(
                        label: 'Asignación de Unidades',
                        icon: Icons.link_rounded,
                        isAvailable: false,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // PAQUETE 2: SEGURIDAD Y ACCESOS
                  _PackageAccordion(
                    id: 'paquete2',
                    title: 'Seguridad y Accesos',
                    icon: Icons.shield_outlined,
                    isExpanded: _isExpanded('paquete2'),
                    onToggle: () => _togglePackage('paquete2'),
                    activeCount: _countAvailableSecurity(user),
                    items: [
                      _DrawerSubItem(
                        label: 'Visitantes y Autorizaciones',
                        icon: Icons.how_to_reg_outlined,
                        route: AppRoute.visitorAuthorizations.path,
                        isActive: currentLocation.startsWith('/autorizaciones-visita'),
                        isAvailable: true,
                      ),
                      _DrawerSubItem(
                        label: 'Pases QR de Visita',
                        icon: Icons.qr_code_2_rounded,
                        route: AppRoute.visitorAuthorizations.path,
                        isActive: currentLocation.startsWith('/qr-visita'),
                        isAvailable: true,
                      ),
                      if (user?.canValidateVisits ?? false)
                        _DrawerSubItem(
                          label: 'Escanear QR en Portería',
                          icon: Icons.qr_code_scanner_rounded,
                          route: AppRoute.visitQrScanner.path,
                          isActive: currentLocation == AppRoute.visitQrScanner.path,
                          isAvailable: true,
                        ),
                      if (user?.canUseSecurityShifts ?? false)
                        _DrawerSubItem(
                          label: 'Turnos de seguridad',
                          icon: Icons.schedule_rounded,
                          route: AppRoute.securityShifts.path,
                          isActive: currentLocation == AppRoute.securityShifts.path,
                          isAvailable: true,
                        ),
                      _DrawerSubItem(
                        label: 'Visitas y personas dentro',
                        icon: Icons.people_alt_outlined,
                        route: AppRoute.visitConsultation.path,
                        isActive: currentLocation == AppRoute.visitConsultation.path,
                        isAvailable: true,
                      ),
                      if (user?.canUseSecurityShifts ?? false)
                        _DrawerSubItem(
                          label: 'Novedades de turno',
                          icon: Icons.edit_note_rounded,
                          route: AppRoute.shiftLogs.path,
                          isActive: currentLocation == AppRoute.shiftLogs.path,
                          isAvailable: true,
                        ),
                      if (user?.canUseSecurityShifts ?? false)
                        _DrawerSubItem(
                          label: 'Entrega y recepción',
                          icon: Icons.swap_horiz_rounded,
                          route: AppRoute.handovers.path,
                          isActive: currentLocation == AppRoute.handovers.path,
                          isAvailable: true,
                        ),
                      const _DrawerSubItem(
                        label: 'Auditoría y Bitácora',
                        icon: Icons.description_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Verificación Facial',
                        icon: Icons.face_retouching_natural_rounded,
                        route: AppRoute.faceVerification.path,
                        isActive: currentLocation == AppRoute.faceVerification.path,
                        isAvailable: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // PAQUETE 3: INCIDENCIAS E IA
                  _PackageAccordion(
                    id: 'paquete3',
                    title: 'Incidencias e IA',
                    icon: Icons.warning_amber_rounded,
                    isExpanded: _isExpanded('paquete3'),
                    onToggle: () => _togglePackage('paquete3'),
                    activeCount: 0,
                    items: const [
                      _DrawerSubItem(
                        label: 'Reportar Incidencia',
                        icon: Icons.report_problem_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Seguimiento y Ciclo',
                        icon: Icons.alt_route_rounded,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Clasificación con IA',
                        icon: Icons.auto_awesome_outlined,
                        isAvailable: false,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // PAQUETE 4: ACTIVOS Y MANTENIMIENTO
                  _PackageAccordion(
                    id: 'paquete4',
                    title: 'Activos y Mantenimiento',
                    icon: Icons.inventory_2_outlined,
                    isExpanded: _isExpanded('paquete4'),
                    onToggle: () => _togglePackage('paquete4'),
                    activeCount: 0,
                    items: const [
                      _DrawerSubItem(
                        label: 'Inventario de Activos',
                        icon: Icons.inventory_2_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Identificación QR',
                        icon: Icons.qr_code_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Órdenes de Trabajo',
                        icon: Icons.build_outlined,
                        isAvailable: false,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // PAQUETE 5: SERVICIOS Y COMUNIDAD
                  _PackageAccordion(
                    id: 'paquete5',
                    title: 'Servicios y Comunidad',
                    icon: Icons.layers_outlined,
                    isExpanded: _isExpanded('paquete5'),
                    onToggle: () => _togglePackage('paquete5'),
                    activeCount: 0,
                    items: const [
                      _DrawerSubItem(
                        label: 'Áreas Comunes y Reservas',
                        icon: Icons.calendar_month_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Comunicados y Avisos',
                        icon: Icons.campaign_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Asambleas y Acuerdos',
                        icon: Icons.account_balance_outlined,
                        isAvailable: false,
                      ),
                      _DrawerSubItem(
                        label: 'Dashboard y Reportes',
                        icon: Icons.bar_chart_outlined,
                        isAvailable: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ASIDE BOTTOM (Tenant Pill + Mini Profile + Logout, igual que Web)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                color: Color(0xFFFBFDFF),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ACTIVE TENANT PILL (Multi-Tenant SaaS)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Icon(
                            Icons.apartment_rounded,
                            color: Color(0xFF0F6FFF),
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONDOMINIO',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                user?.activeTenant?.name ?? 'Condominio Taji',
                                style: const TextStyle(
                                  color: Color(0xFF10233C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (user?.activeTenant?.slug != null && user!.activeTenant!.slug.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user.activeTenant!.slug,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // MINI PROFILE ROW
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          user?.initials ?? 'TA',
                          style: const TextStyle(
                            color: Color(0xFF075AD7),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Usuario Taji',
                              style: const TextStyle(
                                color: Color(0xFF10233C),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              roleName,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await auth.logout();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countAvailableSecurity(TajiUser? user) {
    int count = 4; // Visitantes, Pases QR, Personas dentro, Verificación facial
    if (user?.canValidateVisits ?? false) count++;
    if (user?.canUseSecurityShifts ?? false) count += 3;
    return count;
  }

  void _showCondominiumInfo(BuildContext context, TajiUser? user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.apartment_rounded, color: Color(0xFF0F6FFF), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Mi Condominio & SaaS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instancia SaaS Multi-Tenant Activa:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              user?.activeTenant?.name ?? 'Condominio Taji',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF10233C)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Identificador / Slug:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(
                        user?.activeTenant?.slug ?? 'taji',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tu Rol:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(
                        user?.role?.name ?? 'Residente',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF075AD7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DirectNavItem extends StatelessWidget {
  const _DirectNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEAF4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFF075AD7) : const Color(0xFF475569),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? const Color(0xFF075AD7) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageAccordion extends StatelessWidget {
  const _PackageAccordion({
    required this.id,
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.items,
    this.activeCount = 0,
  });

  final String id;
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> items;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TRIGGER BUTTON (Estilo Web .package-trigger)
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isExpanded ? const Color(0xFFF8FAFC) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isExpanded ? FontWeight.w700 : FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activeCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ACCORDION CONTENT (Con línea vertical de guía, igual que Web)
        if (isExpanded)
          Container(
            margin: const EdgeInsets.only(left: 19, top: 4, bottom: 6),
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ),
      ],
    );
  }
}

class _DrawerSubItem extends StatelessWidget {
  const _DrawerSubItem({
    required this.label,
    required this.icon,
    this.route,
    this.isActive = false,
    this.isAvailable = true,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String? route;
  final bool isActive;
  final bool isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFFCBD5E1)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Pronto',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else if (route != null) {
          Navigator.pop(context);
          context.push(route!);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEAF4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF075AD7) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? const Color(0xFF075AD7) : const Color(0xFF334155),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF0F6FFF),
              ),
          ],
        ),
      ),
    );
  }
}
