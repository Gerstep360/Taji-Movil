import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/taji_theme.dart';
import '../../features/auth/state/auth_controller.dart';
import 'taji_logo.dart';

class TajiDrawer extends StatelessWidget {
  const TajiDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final roleName = user?.role?.name ?? 'Residente';

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // USER & BRAND HEADER
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 24,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF075FDD), Color(0xFF1489FF)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TajiLogo(light: true),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        child: Text(
                          user?.initials ?? 'TA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Usuario Taji',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    roleName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // MULTI-TENANT INSTANCE PILL
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apartment_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONDOMINIO ACTIVO',
                                style: TextStyle(
                                  color: Color(0xC0FFFFFF),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                user?.activeTenant?.name ?? 'Condominio Taji',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (user?.activeTenant?.slug != null && user!.activeTenant!.slug.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.activeTenant!.slug,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // DRAWER NAVIGATION ITEMS BY PACKAGE
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  // INICIO DIRECTO
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    title: 'Inicio / Panel',
                    isSelected: GoRouterState.of(context).matchedLocation == AppRoute.home.path,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoute.home.path);
                    },
                  ),

                  const Divider(height: 18, color: TajiColors.border),

                  // PAQUETE 1
                  _PackageHeader(title: 'Paquete 1: Usuarios y Comunidad'),
                  _DrawerItem(
                    icon: Icons.badge_outlined,
                    title: 'Mi Perfil de Usuario',
                    subtitle: 'Datos personales y rol',
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoute.home.path);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.business_outlined,
                    title: 'Mi Condominio & SaaS',
                    subtitle: user?.activeTenant?.name ?? 'Instancia activa',
                    iconColor: const Color(0xFF0F6FFF),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Instancia activa: ${user?.activeTenant?.name ?? "Taji Condominio"} (Multi-Tenant SaaS)',
                          ),
                        ),
                      );
                    },
                  ),

                  // PAQUETE 2: SEGURIDAD Y ACCESOS
                  _PackageHeader(title: 'Paquete 2: Seguridad y Accesos'),
                  _DrawerItem(
                    icon: Icons.qr_code_2_rounded,
                    title: 'Pases QR de Visita (CU09)',
                    subtitle: 'Generar y consultar pases de acceso',
                    iconColor: const Color(0xFF0F6FFF),
                    isSelected: GoRouterState.of(context).matchedLocation.startsWith('/autorizaciones-visita') ||
                        GoRouterState.of(context).matchedLocation.startsWith('/qr-visita'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoute.visitorAuthorizations.path);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Escanear QR en Portería (CU10)',
                    subtitle: 'Validación en vivo con cámara',
                    iconColor: const Color(0xFF059669),
                    isSelected: GoRouterState.of(context).matchedLocation == AppRoute.visitQrScanner.path,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoute.visitQrScanner.path);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.face_retouching_natural_rounded,
                    title: 'Verificación Facial (CU17)',
                    subtitle: 'Reconocimiento biométrico con cámara',
                    iconColor: const Color(0xFF7C3AED),
                    isSelected: GoRouterState.of(context).matchedLocation == AppRoute.faceVerification.path,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoute.faceVerification.path);
                    },
                  ),

                  // PAQUETE 3
                  _PackageHeader(title: 'Paquete 3: Áreas Comunes'),
                  _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    title: 'Reservas de Áreas',
                    isPending: true,
                    onTap: () {},
                  ),

                  // PAQUETE 4
                  _PackageHeader(title: 'Paquete 4: Finanzas'),
                  _DrawerItem(
                    icon: Icons.credit_card_outlined,
                    title: 'Expensas y Pagos',
                    isPending: true,
                    onTap: () {},
                  ),

                  // PAQUETE 5
                  _PackageHeader(title: 'Paquete 5: Servicios y Comunidad'),
                  _DrawerItem(
                    icon: Icons.campaign_outlined,
                    title: 'Comunicados y Avisos',
                    isPending: true,
                    onTap: () {},
                  ),
                  _DrawerItem(
                    icon: Icons.report_problem_outlined,
                    title: 'Reporte de Incidentes',
                    isPending: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // LOGOUT BUTTON
            const Divider(height: 1, color: TajiColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await auth.logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageHeader extends StatelessWidget {
  const _PackageHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isSelected = false,
    this.isPending = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isPending;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isPending
        ? const Color(0xFF94A3B8)
        : (isSelected ? const Color(0xFF0F6FFF) : (iconColor ?? const Color(0xFF10233C)));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEAF4FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
        leading: Icon(icon, color: effectiveIconColor, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isPending
                ? const Color(0xFF94A3B8)
                : (isSelected ? const Color(0xFF075AD7) : const Color(0xFF10233C)),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6F7F93)),
              )
            : null,
        trailing: isPending
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pronto',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : (isSelected
                ? const Icon(Icons.chevron_right, size: 18, color: Color(0xFF0F6FFF))
                : null),
        onTap: isPending ? null : onTap,
      ),
    );
  }
}
