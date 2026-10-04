import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/taji_theme.dart';
import '../../../shared/widgets/taji_drawer.dart';
import '../../../shared/widgets/taji_logo.dart';
import '../state/auth_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user!;
    final role = user.role;

    return Scaffold(
      drawer: const TajiDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: TajiColors.ink),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const TajiLogo(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: TajiColors.primarySoft,
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: TajiColors.primaryStrong,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          children: [
            Text(
              'PANEL PRINCIPAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TajiColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Hola, ${user.firstName}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: TajiColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_rounded, color: TajiColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        user.activeTenant?.name ?? 'Condominio Taji',
                        style: const TextStyle(
                          color: TajiColors.primaryStrong,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user.activeTenant?.slug != null && user.activeTenant!.slug.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${user.activeTenant!.slug}',
                          style: const TextStyle(
                            color: TajiColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // WELCOME HERO CARD
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF075FDD), Color(0xFF1489FF)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2B0F6FFF),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      role?.name.toUpperCase() ?? 'RESIDENTE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Comunidad Conectada\ny Segura',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Accede a los módulos de seguridad, pases QR y biometría desde los accesos rápidos o el menú lateral.',
                    style: TextStyle(
                      color: Color(0xE0FFFFFF),
                      height: 1.45,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // QUICK ACTIONS TITLE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MÓDULOS DISPONIBLES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: TajiColors.muted,
                  ),
                ),
                Text(
                  'Paquete 2: Seguridad',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TajiColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ACTION CARDS
            _ActionCard(
              icon: Icons.qr_code_2_rounded,
              iconColor: const Color(0xFF0F6FFF),
              iconBackground: const Color(0xFFEAF4FF),
              title: 'Pases QR de Visita (CU09)',
              subtitle: 'Genera códigos QR temporales y seguros para tus visitas',
              onTap: () => context.push(AppRoute.visitorAuthorizations.path),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.qr_code_scanner_rounded,
              iconColor: const Color(0xFF059669),
              iconBackground: const Color(0xFFECFDF5),
              title: 'Lector QR en Portería (CU10)',
              subtitle: 'Escaneo con cámara y verificación de validez de visitas',
              onTap: () => context.push(AppRoute.visitQrScanner.path),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.face_retouching_natural_rounded,
              iconColor: const Color(0xFF7C3AED),
              iconBackground: const Color(0xFFF5F3FF),
              title: 'Verificación Facial (CU17)',
              subtitle: 'Captura fotográfica y cotejo biométrico en garita',
              onTap: () => context.push(AppRoute.faceVerification.path),
            ),

            const SizedBox(height: 24),

            // SYSTEM STATUS CARDS
            const Text(
              'ESTADO DE LA CUENTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: TajiColors.muted,
              ),
            ),
            const SizedBox(height: 12),

            _InfoCard(
              icon: Icons.badge_outlined,
              iconColor: TajiColors.primary,
              iconBackground: TajiColors.primarySoft,
              label: 'Rol asignado',
              value: role?.name ?? 'Sin asignar',
            ),
            const SizedBox(height: 10),
            const _InfoCard(
              icon: Icons.verified_user_outlined,
              iconColor: TajiColors.success,
              iconBackground: TajiColors.successSoft,
              label: 'Estado de acceso',
              value: 'Aprobado y Activo',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TajiColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: TajiColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TajiColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: TajiColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TajiColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: TajiColors.muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: TajiColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
