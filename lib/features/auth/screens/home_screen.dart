import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/taji_theme.dart';
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
              'PANEL PERSONAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TajiColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Hola, ${user.firstName} 👋',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF075FDD), Color(0xFF1489FF)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2B0F6FFF),
                    blurRadius: 30,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'ACCESO CONFIRMADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bienvenido a tu\ncomunidad Taji',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.06,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tu cuenta está lista. Los módulos se habilitarán en las siguientes etapas.',
                    style: TextStyle(
                      color: Color(0xC9FFFFFF),
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _InfoCard(
              icon: Icons.badge_outlined,
              iconColor: TajiColors.primary,
              iconBackground: TajiColors.primarySoft,
              label: 'Tu rol',
              value: role?.name ?? 'Sin asignar',
            ),
            const SizedBox(height: 10),
            const _InfoCard(
              icon: Icons.verified_user_outlined,
              iconColor: TajiColors.success,
              iconBackground: Color(0xFFE5F9F0),
              label: 'Estado de cuenta',
              value: 'Activa y protegida',
            ),
            const SizedBox(height: 18),
            _Panel(
              title: 'Permisos de tu rol',
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: (role?.permissions ?? [])
                    .map(
                      (permission) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFF),
                          border: Border.all(color: const Color(0xFFDFE9F7)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _permissionLabel(permission),
                          style: const TextStyle(
                            color: Color(0xFF47627F),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            _Panel(
              title: 'Tus datos',
              child: Column(
                children: [
                  _DataRow(label: 'Nombre', value: user.fullName),
                  _DataRow(label: 'Correo', value: user.email),
                  _DataRow(
                    label: 'Teléfono',
                    value: user.phone.isEmpty ? 'No registrado' : user.phone,
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: auth.busy ? null : auth.logout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: TajiColors.danger,
                side: const BorderSide(color: Color(0xFFFFD8DD)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 19),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  String _permissionLabel(String code) {
    final value = code.replaceAll('_', ' ');
    return '${value[0].toUpperCase()}${value.substring(1)}';
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: TajiColors.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: TajiColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: TajiColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: TajiColors.border),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: TajiColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value, this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFFEDF1F5))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: TajiColors.muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: TajiColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
