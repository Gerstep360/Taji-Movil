import 'package:flutter/material.dart';

/// Fecha local `dd/MM/yyyy HH:mm`; `fallback` cuando no hay fecha.
String formatAssemblyDate(DateTime? value, {String fallback = 'Sin fecha'}) {
  if (value == null) return fallback;
  final local = value.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year} '
      '${pad(local.hour)}:${pad(local.minute)}';
}

/// Importe con dos decimales, o `—` si no está registrado.
String formatMoney(String? value) {
  final parsed = double.tryParse(value ?? '');
  return parsed == null ? '—' : parsed.toStringAsFixed(2);
}

Color statusColor(String status) => switch (status) {
  'SCHEDULED' || 'PENDING' => Colors.blue.shade700,
  'IN_PROGRESS' => Colors.orange.shade800,
  'FINISHED' || 'COMPLETED' => Colors.green.shade700,
  'OVERDUE' => Colors.red.shade700,
  _ => Colors.blueGrey.shade600,
};

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
